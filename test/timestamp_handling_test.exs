defmodule ExPostFactoTimestampHandlingTest do
  use ExUnit.Case, async: true

  alias ExPostFacto.InputData

  describe "normalize_timestamp/1" do
    test "returns nil for nil input" do
      assert InputData.normalize_timestamp(nil) == nil
    end

    test "returns DateTime unchanged" do
      dt = ~U[2023-01-01 12:00:00Z]
      assert InputData.normalize_timestamp(dt) == dt
    end

    test "parses ISO 8601 timestamp" do
      iso_string = "2023-01-01T12:00:00Z"
      result = InputData.normalize_timestamp(iso_string)

      assert %DateTime{} = result
      assert result.year == 2023
      assert result.month == 1
      assert result.day == 1
    end

    test "parses date-only string" do
      date_string = "2023-01-01"
      result = InputData.normalize_timestamp(date_string)

      assert %DateTime{} = result
      assert result.year == 2023
      assert result.month == 1
      assert result.day == 1
      assert result.hour == 0
      assert result.minute == 0
    end

    test "parses Unix timestamp string" do
      # 2023-01-01 00:00:00 UTC
      unix_string = "1672531200"
      result = InputData.normalize_timestamp(unix_string)

      assert %DateTime{} = result
      assert result.year == 2023
      assert result.month == 1
      assert result.day == 1
    end

    test "returns original string for unparseable format" do
      unparseable = "not a timestamp"
      result = InputData.normalize_timestamp(unparseable)

      assert result == unparseable
    end

    test "handles other data types gracefully" do
      number = 12345
      result = InputData.normalize_timestamp(number)

      assert result == number
    end
  end

  describe "munge/1 with timestamp normalization" do
    test "normalizes timestamp in data" do
      data = %{
        open: 100.0,
        high: 105.0,
        low: 98.0,
        close: 102.0,
        timestamp: "2023-01-01"
      }

      result = InputData.munge(data)

      assert %DateTime{} = result.timestamp
      assert result.timestamp.year == 2023
      assert result.timestamp.month == 1
      assert result.timestamp.day == 1
    end

    test "normalizes short timestamp key" do
      data = %{
        o: 100.0,
        h: 105.0,
        l: 98.0,
        c: 102.0,
        t: "2023-01-01T12:00:00Z"
      }

      result = InputData.munge(data)

      assert %DateTime{} = result.timestamp
    end

    test "handles missing timestamp gracefully" do
      data = %{
        open: 100.0,
        high: 105.0,
        low: 98.0,
        close: 102.0
      }

      result = InputData.munge(data)

      assert result.timestamp == nil
    end

    test "preserves unparseable timestamps" do
      data = %{
        open: 100.0,
        high: 105.0,
        low: 98.0,
        close: 102.0,
        timestamp: "custom_format_2023"
      }

      result = InputData.munge(data)

      assert result.timestamp == "custom_format_2023"
    end
  end

  describe "new!/1 with timestamp normalization" do
    test "normalizes timestamp in new! function" do
      data = %{
        high: 105.0,
        low: 98.0,
        open: 100.0,
        close: 102.0,
        volume: 1000.0,
        timestamp: "2023-01-01"
      }

      result = InputData.new!(data)

      assert %DateTime{} = result.timestamp
      assert result.timestamp.year == 2023
    end

    test "handles DateTime input in new! function" do
      dt = ~U[2023-01-01 12:00:00Z]

      data = %{
        high: 105.0,
        low: 98.0,
        open: 100.0,
        close: 102.0,
        volume: 1000.0,
        timestamp: dt
      }

      result = InputData.new!(data)

      assert result.timestamp == dt
    end
  end
end
