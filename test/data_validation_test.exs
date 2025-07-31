defmodule ExPostFactoDataValidationTest do
  use ExUnit.Case, async: true
  doctest ExPostFacto

  describe "validate_data/1" do
    test "returns :ok for valid OHLC data" do
      valid_data = [
        %{open: 1.0, high: 2.0, low: 0.5, close: 1.5},
        %{open: 1.5, high: 2.5, low: 1.0, close: 2.0}
      ]

      assert :ok == ExPostFacto.validate_data(valid_data)
    end

    test "returns :ok for valid OHLC data with short keys" do
      valid_data = [
        %{o: 1.0, h: 2.0, l: 0.5, c: 1.5},
        %{o: 1.5, h: 2.5, l: 1.0, c: 2.0}
      ]

      assert :ok == ExPostFacto.validate_data(valid_data)
    end

    test "returns :ok for single valid data point" do
      valid_point = %{open: 1.0, high: 2.0, low: 0.5, close: 1.5}

      assert :ok == ExPostFacto.validate_data(valid_point)
    end

    test "returns error for empty data" do
      assert {:error, "data cannot be empty"} == ExPostFacto.validate_data([])
    end

    test "returns error for nil data" do
      assert {:error, "data cannot be nil"} == ExPostFacto.validate_data(nil)
    end

    test "returns error for invalid OHLC relationship - high < low" do
      invalid_data = [%{open: 1.0, high: 1.0, low: 2.0, close: 1.5}]

      assert {:error, "data point 0: invalid OHLC data: high (1.0) must be >= low (2.0)"} ==
               ExPostFacto.validate_data(invalid_data)
    end

    test "returns error for invalid OHLC relationship - open > high" do
      invalid_data = [%{open: 3.0, high: 2.0, low: 1.0, close: 1.5}]

      assert {:error, "data point 0: invalid OHLC data: open (3.0) must be <= high (2.0)"} ==
               ExPostFacto.validate_data(invalid_data)
    end

    test "returns error for invalid OHLC relationship - open < low" do
      invalid_data = [%{open: 0.5, high: 2.0, low: 1.0, close: 1.5}]

      assert {:error, "data point 0: invalid OHLC data: open (0.5) must be >= low (1.0)"} ==
               ExPostFacto.validate_data(invalid_data)
    end

    test "returns error for invalid OHLC relationship - close > high" do
      invalid_data = [%{open: 1.5, high: 2.0, low: 1.0, close: 2.5}]

      assert {:error, "data point 0: invalid OHLC data: close (2.5) must be <= high (2.0)"} ==
               ExPostFacto.validate_data(invalid_data)
    end

    test "returns error for invalid OHLC relationship - close < low" do
      invalid_data = [%{open: 1.5, high: 2.0, low: 1.0, close: 0.5}]

      assert {:error, "data point 0: invalid OHLC data: close (0.5) must be >= low (1.0)"} ==
               ExPostFacto.validate_data(invalid_data)
    end

    test "returns error for missing required fields" do
      invalid_data = [%{open: 1.0, high: 2.0, low: 0.5}]

      assert {:error, "data point 0: missing required OHLC fields"} ==
               ExPostFacto.validate_data(invalid_data)
    end

    test "returns error for nil values" do
      invalid_data = [%{open: nil, high: 2.0, low: 0.5, close: 1.5}]

      assert {:error, "data point 0: OHLC values cannot be nil"} ==
               ExPostFacto.validate_data(invalid_data)
    end

    test "returns error for non-numeric values" do
      invalid_data = [%{open: "1.0", high: 2.0, low: 0.5, close: 1.5}]

      assert {:error, "data point 0: OHLC values must be numeric"} ==
               ExPostFacto.validate_data(invalid_data)
    end

    test "returns error for negative values" do
      invalid_data = [%{open: -1.0, high: 2.0, low: 0.5, close: 1.5}]

      assert {:error, "data point 0: OHLC values must be non-negative"} ==
               ExPostFacto.validate_data(invalid_data)
    end

    test "returns error for non-map data points" do
      invalid_data = ["not a map"]

      assert {:error, "data point 0: data point must be a map"} ==
               ExPostFacto.validate_data(invalid_data)
    end

    test "validates data with optional volume and timestamp fields" do
      valid_data = [
        %{open: 1.0, high: 2.0, low: 0.5, close: 1.5, volume: 1000, timestamp: "2023-01-01"}
      ]

      assert :ok == ExPostFacto.validate_data(valid_data)
    end
  end

  describe "clean_data/1" do
    test "returns empty list for empty input" do
      assert {:ok, []} == ExPostFacto.clean_data([])
    end

    test "returns error for nil input" do
      assert {:error, "data cannot be nil"} == ExPostFacto.clean_data(nil)
    end

    test "removes invalid data points" do
      dirty_data = [
        # valid
        %{open: 1.0, high: 2.0, low: 0.5, close: 1.5},
        # invalid - nil value
        %{open: nil, high: 2.0, low: 0.5, close: 1.5},
        # invalid - high < low
        %{open: 1.0, high: 1.0, low: 2.0, close: 1.5}
      ]

      {:ok, cleaned} = ExPostFacto.clean_data(dirty_data)

      assert length(cleaned) == 1
      assert hd(cleaned) == %{open: 1.0, high: 2.0, low: 0.5, close: 1.5}
    end

    test "sorts data by timestamp" do
      unsorted_data = [
        %{open: 1.0, high: 2.0, low: 0.5, close: 1.5, timestamp: "2023-01-03"},
        %{open: 1.2, high: 2.2, low: 0.7, close: 1.7, timestamp: "2023-01-01"},
        %{open: 1.1, high: 2.1, low: 0.6, close: 1.6, timestamp: "2023-01-02"}
      ]

      {:ok, cleaned} = ExPostFacto.clean_data(unsorted_data)

      timestamps = Enum.map(cleaned, & &1.timestamp)
      assert timestamps == ["2023-01-01", "2023-01-02", "2023-01-03"]
    end

    test "removes duplicate timestamps" do
      data_with_duplicates = [
        %{open: 1.0, high: 2.0, low: 0.5, close: 1.5, timestamp: "2023-01-01"},
        # duplicate timestamp
        %{open: 1.1, high: 2.1, low: 0.6, close: 1.6, timestamp: "2023-01-01"},
        %{open: 1.2, high: 2.2, low: 0.7, close: 1.7, timestamp: "2023-01-02"}
      ]

      {:ok, cleaned} = ExPostFacto.clean_data(data_with_duplicates)

      assert length(cleaned) == 2
      timestamps = Enum.map(cleaned, & &1.timestamp)
      assert timestamps == ["2023-01-01", "2023-01-02"]
    end

    test "handles data without timestamps" do
      data_without_timestamps = [
        %{open: 1.0, high: 2.0, low: 0.5, close: 1.5},
        %{open: 1.2, high: 2.2, low: 0.7, close: 1.7}
      ]

      {:ok, cleaned} = ExPostFacto.clean_data(data_without_timestamps)

      assert length(cleaned) == 2
    end

    test "handles mixed timestamp formats" do
      mixed_data = [
        # short key
        %{open: 1.0, high: 2.0, low: 0.5, close: 1.5, t: "2023-01-01"},
        # long key
        %{open: 1.2, high: 2.2, low: 0.7, close: 1.7, timestamp: "2023-01-02"}
      ]

      {:ok, cleaned} = ExPostFacto.clean_data(mixed_data)

      assert length(cleaned) == 2
    end
  end
end
