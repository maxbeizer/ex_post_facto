defmodule ExPostFactoIntegrationTest do
  use ExUnit.Case, async: true

  alias ExPostFacto.ExampleStrategies.Noop

  describe "integration tests with real data" do
    test "validates and processes ORCL CSV data" do
      # Test with the existing ORCL fixture
      csv_path = "test/fixtures/orcl-1995-2014.txt"

      # Load data using new CSV functionality
      {:ok, data} = ExPostFacto.load_data_from_source(csv_path)

      # Should load many data points
      assert length(data) > 1000

      # Validate the data structure
      assert :ok = ExPostFacto.validate_data(data)

      # Clean the data
      {:ok, cleaned_data} = ExPostFacto.clean_data(data)

      # Should be properly sorted by timestamp
      timestamps = Enum.map(cleaned_data, & &1.timestamp)
      assert timestamps == Enum.sort(timestamps)

      # Run backtest with cleaned data
      {:ok, output} = ExPostFacto.backtest(cleaned_data, {Noop, :noop, []})

      assert %ExPostFacto.Output{} = output
    end

    test "backtest works directly with CSV file path" do
      csv_path = "test/fixtures/orcl-1995-2014.txt"

      # Should work directly with file path
      {:ok, output} = ExPostFacto.backtest(csv_path, {Noop, :noop, []})

      assert %ExPostFacto.Output{} = output
      assert output.result.starting_balance == 0.0
    end

    test "backtest with CSV file and custom starting balance" do
      csv_path = "test/fixtures/orcl-1995-2014.txt"

      {:ok, output} = ExPostFacto.backtest(csv_path, {Noop, :noop, []}, starting_balance: 100_000.0)

      assert %ExPostFacto.Output{} = output
      assert output.result.starting_balance == 100_000.0
    end

    test "demonstrates data validation with mixed quality data" do
      # Create a mixed quality dataset
      mixed_data = [
        # Valid data points
        %{open: 100.0, high: 105.0, low: 98.0, close: 102.0, timestamp: "2023-01-01"},
        %{open: 102.0, high: 108.0, low: 101.0, close: 106.0, timestamp: "2023-01-02"},

        # Invalid data points that should be filtered out
        %{open: nil, high: 105.0, low: 98.0, close: 102.0, timestamp: "2023-01-03"},  # nil value
        %{open: 100.0, high: 95.0, low: 98.0, close: 102.0, timestamp: "2023-01-04"}, # high < low
        %{open: -1.0, high: 105.0, low: 98.0, close: 102.0, timestamp: "2023-01-05"}, # negative price

        # More valid data
        %{open: 106.0, high: 110.0, low: 104.0, close: 108.0, timestamp: "2023-01-06"}
      ]

      # Validate original data - should fail
      {:error, _reason} = ExPostFacto.validate_data(mixed_data)

      # Clean the data - should remove invalid points
      {:ok, cleaned_data} = ExPostFacto.clean_data(mixed_data)

      # Should only have 3 valid data points
      assert length(cleaned_data) == 3

      # Validate cleaned data - should pass
      assert :ok = ExPostFacto.validate_data(cleaned_data)

      # Should work with backtest
      {:ok, output} = ExPostFacto.backtest(cleaned_data, {Noop, :noop, []})
      assert %ExPostFacto.Output{} = output
    end

    test "demonstrates timestamp normalization across formats" do
      mixed_timestamp_data = [
        %{open: 100.0, high: 105.0, low: 98.0, close: 102.0, timestamp: "2023-01-01"},           # Date string
        %{open: 102.0, high: 108.0, low: 101.0, close: 106.0, timestamp: "2023-01-02T12:00:00Z"}, # ISO 8601
        %{open: 106.0, high: 110.0, low: 104.0, close: 108.0, t: "1672790400"}                    # Unix timestamp
      ]

      # Load and process the data
      alias ExPostFacto.InputData
      processed_data = Enum.map(mixed_timestamp_data, &InputData.munge/1)

      # All timestamps should be normalized to DateTime structs or kept as strings
      Enum.each(processed_data, fn point ->
        assert point.timestamp != nil
        # Should be either DateTime struct or original string if unparseable
        assert is_struct(point.timestamp, DateTime) or is_binary(point.timestamp)
      end)

      # Should work with backtest
      {:ok, output} = ExPostFacto.backtest(mixed_timestamp_data, {Noop, :noop, []})
      assert %ExPostFacto.Output{} = output
    end

    test "performance with large dataset validation and cleaning" do
      # Create a large dataset (simulating real-world scenario)
      large_dataset = Enum.map(1..1000, fn i ->
        # Generate valid OHLC data by ensuring proper relationships
        base_price = 100.0
        open = base_price + (:rand.uniform() - 0.5) * 10  # 95-105 range
        close = base_price + (:rand.uniform() - 0.5) * 10  # 95-105 range

        # Ensure high is at least as high as max(open, close)
        min_high = max(open, close)
        high = min_high + :rand.uniform() * 5  # At least min_high, up to min_high + 5

        # Ensure low is at most as low as min(open, close)
        max_low = min(open, close)
        low = max_low - :rand.uniform() * 5  # At most max_low, down to max_low - 5

        %{
          open: open,
          high: high,
          low: low,
          close: close,
          volume: :rand.uniform(1_000_000),
          timestamp: "2023-01-#{:io_lib.format("~2..0B", [rem(i, 28) + 1])}"
        }
      end)

      # Measure validation time
      start_time = System.monotonic_time(:millisecond)
      assert :ok = ExPostFacto.validate_data(large_dataset)
      validation_time = System.monotonic_time(:millisecond) - start_time

      # Should complete validation reasonably quickly (< 1 second for 1000 points)
      assert validation_time < 1000

      # Measure cleaning time
      start_time = System.monotonic_time(:millisecond)
      {:ok, _cleaned} = ExPostFacto.clean_data(large_dataset)
      cleaning_time = System.monotonic_time(:millisecond) - start_time

      # Should complete cleaning reasonably quickly
      assert cleaning_time < 1000
    end
  end

  describe "error handling and edge cases" do
    test "handles empty CSV file gracefully" do
      # Create temporary empty CSV file
      empty_csv = "/tmp/empty.csv"
      File.write!(empty_csv, "")

      {:error, reason} = ExPostFacto.load_data_from_source(empty_csv)
      assert String.contains?(reason, "empty")

      # Clean up
      File.rm(empty_csv)
    end

    test "handles malformed CSV data gracefully" do
      # Create temporary malformed CSV file
      malformed_csv = "/tmp/malformed.csv"
      File.write!(malformed_csv, "Date,Open,High,Low,Close\n2023-01-01,not_a_number,105,98,102")

      # Should still load but with string values
      {:ok, data} = ExPostFacto.load_data_from_source(malformed_csv)
      assert length(data) == 1

      # Validation should catch the invalid data
      {:error, _reason} = ExPostFacto.validate_data(data)

      # Clean up
      File.rm(malformed_csv)
    end

    test "handles very large individual values" do
      extreme_data = [
        %{open: 1.0e10, high: 1.1e10, low: 0.9e10, close: 1.05e10}
      ]

      # Should validate successfully (very large but valid numbers)
      assert :ok = ExPostFacto.validate_data(extreme_data)
    end

    test "handles very small individual values" do
      tiny_data = [
        %{open: 1.0e-10, high: 1.1e-10, low: 0.9e-10, close: 1.05e-10}
      ]

      # Should validate successfully (very small but valid numbers)
      assert :ok = ExPostFacto.validate_data(tiny_data)
    end
  end
end
