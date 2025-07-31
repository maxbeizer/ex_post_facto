defmodule ExPostFactoDataFormatsTest do
  use ExUnit.Case, async: true

  alias ExPostFacto.ExampleStrategies.Noop

  describe "load_data_from_source/1" do
    test "loads CSV data from file" do
      {:ok, data} = ExPostFacto.load_data_from_source("test/fixtures/sample.csv")

      assert length(data) == 3
      assert %{open: 100.0, high: 105.0, low: 98.0, close: 102.0, volume: 1_000_000.0, timestamp: "2023-01-01"} = hd(data)
    end

    test "returns error for non-existent file" do
      assert {:error, "failed to read file: enoent"} = ExPostFacto.load_data_from_source("nonexistent.csv")
    end

    test "parses simple JSON array" do
      json_data = ~s([{"open": 100.0, "high": 105.0, "low": 98.0, "close": 102.0}])

      {:ok, data} = ExPostFacto.load_data_from_source(json_data)

      assert length(data) == 1
      assert %{"open" => 100.0, "high" => 105.0, "low" => 98.0, "close" => 102.0} = hd(data)
    end

    test "returns error for unsupported format" do
      assert {:error, "unsupported data format or file not found"} = ExPostFacto.load_data_from_source("unknown_format")
    end
  end

  describe "backtest/3 with multiple input formats" do
    test "accepts CSV file path" do
      {:ok, output} = ExPostFacto.backtest("test/fixtures/sample.csv", {Noop, :noop, []})

      assert %ExPostFacto.Output{} = output
      assert length(output.result.data_points) >= 0
    end

    test "accepts list of maps (existing functionality)" do
      data = [%{open: 100.0, high: 105.0, low: 98.0, close: 102.0}]

      {:ok, output} = ExPostFacto.backtest(data, {Noop, :noop, []})

      assert %ExPostFacto.Output{} = output
    end

    test "validates data by default" do
      invalid_data = [%{open: 100.0, high: 95.0, low: 98.0, close: 102.0}]  # high < low

      {:error, reason} = ExPostFacto.backtest(invalid_data, {Noop, :noop, []})

      # Invalid OHLC data gets cleaned out, leaving empty dataset
      assert reason == "data cannot be empty"
    end

    test "can skip validation with option" do
      invalid_data = [%{open: 100.0, high: 95.0, low: 98.0, close: 102.0}]  # high < low

      {:ok, output} = ExPostFacto.backtest(invalid_data, {Noop, :noop, []}, validate_data: false)

      assert %ExPostFacto.Output{} = output
    end

    test "cleans data by default" do
      dirty_data = [
        %{open: 100.0, high: 105.0, low: 98.0, close: 102.0, timestamp: "2023-01-02"},
        %{open: nil, high: 105.0, low: 98.0, close: 102.0, timestamp: "2023-01-01"},  # invalid
        %{open: 99.0, high: 104.0, low: 97.0, close: 101.0, timestamp: "2023-01-03"}
      ]

      {:ok, output} = ExPostFacto.backtest(dirty_data, {Noop, :noop, []})

      assert %ExPostFacto.Output{} = output
      # Should have cleaned out the invalid data point
    end

    test "can skip cleaning with option" do
      dirty_data = [
        %{open: 100.0, high: 105.0, low: 98.0, close: 102.0, timestamp: "2023-01-02"},
        %{open: 99.0, high: 104.0, low: 97.0, close: 101.0, timestamp: "2023-01-01"}  # out of order
      ]

      {:ok, output} = ExPostFacto.backtest(dirty_data, {Noop, :noop, []}, clean_data: false)

      assert %ExPostFacto.Output{} = output
    end
  end

  describe "CSV parsing" do
    test "handles different header formats" do
      _csv_content = """
      Date,Open,High,Low,Close,Volume
      2023-01-01,100,105,98,102,1000
      """

      {:ok, data} = ExPostFacto.load_data_from_source("test/fixtures/sample.csv")

      assert hd(data).timestamp == "2023-01-01"
      assert hd(data).open == 100.0
    end

    test "keeps raw Close when both Close and Adj Close are present" do
      csv_content = """
      Date,Open,High,Low,Close,Adj Close,Volume
      2023-01-01,100,105,98,102,101.5,1000
      """

      # Create a temp file for this test
      temp_file = "/tmp/test_adj_close.csv"
      File.write!(temp_file, csv_content)

      {:ok, data} = ExPostFacto.load_data_from_source(temp_file)

      # Should use raw "Close" value, not "Adj Close"
      assert hd(data).close == 102.0
      # Should also have the adj_close value available
      assert hd(data).adj_close == 101.5

      # Clean up
      File.rm(temp_file)
    end
  end
end
