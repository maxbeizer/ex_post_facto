defmodule ExPostFacto.IndicatorsTest do
  use ExUnit.Case, async: true
  doctest ExPostFacto.Indicators

  alias ExPostFacto.Indicators

  describe "sma/2" do
    test "calculates simple moving average correctly" do
      data = [1, 2, 3, 4, 5]
      result = Indicators.sma(data, 3)

      assert result == [nil, nil, 2.0, 3.0, 4.0]
    end

    test "handles edge case with insufficient data" do
      data = [1, 2]
      result = Indicators.sma(data, 3)

      assert result == [nil, nil]
    end

    test "works with period of 1" do
      data = [10, 20, 30]
      result = Indicators.sma(data, 1)

      assert result == [10.0, 20.0, 30.0]
    end

    test "handles empty data" do
      result = Indicators.sma([], 3)
      assert result == []
    end
  end

  describe "ema/2" do
    test "calculates exponential moving average correctly" do
      data = [22.27, 22.19, 22.08, 22.17, 22.18, 22.13, 22.23, 22.43, 22.24, 22.29]
      result = Indicators.ema(data, 10)

      # Last value should be approximately 22.221
      assert length(result) == 10
      assert List.last(result) |> Float.round(3) == 22.221
    end

    test "first EMA value uses SMA calculation" do
      data = [10, 11, 12, 13, 14]
      result = Indicators.ema(data, 3)

      # First EMA should equal SMA of first 3 values: (10+11+12)/3 = 11.0
      assert Enum.at(result, 2) == 11.0
    end

    test "handles insufficient data" do
      data = [1, 2]
      result = Indicators.ema(data, 3)

      assert result == [nil, nil]
    end
  end

  describe "rsi/2" do
    test "calculates RSI correctly for known data" do
      # Using a known dataset for RSI calculation
      data = [
        44,
        44.34,
        44.09,
        44.15,
        43.61,
        44.33,
        44.83,
        45.85,
        46.08,
        45.89,
        46.03,
        46.83,
        47.69,
        46.49,
        46.26,
        46.38
      ]

      result = Indicators.rsi(data, 14)

      # RSI should be calculated starting from index 14 (after 14 periods)
      assert length(result) == 16
      assert List.last(result) |> Float.round(1) |> Kernel.>(50.0)
    end

    test "handles insufficient data" do
      data = [1, 2, 3]
      result = Indicators.rsi(data, 14)

      # Should return nils for insufficient periods
      assert Enum.all?(result, &is_nil/1)
    end

    test "handles edge case with no price changes" do
      data = [50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50, 50]
      result = Indicators.rsi(data, 14)

      # RSI should be around 50 when there are no price changes
      assert List.last(result) |> Float.round(0) == 50.0
    end
  end

  describe "macd/4" do
    test "calculates MACD correctly" do
      data = [12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30]
      {macd_line, signal_line, histogram} = Indicators.macd(data, 5, 10, 3)

      assert length(macd_line) == length(data)
      assert length(signal_line) == length(data)
      assert length(histogram) == length(data)

      # MACD line should have values starting from the slow period
      refute Enum.all?(macd_line, &is_nil/1)

      # Signal line should start later (after signal period)
      signal_non_nil = Enum.filter(signal_line, &(&1 != nil))
      assert length(signal_non_nil) > 0
    end

    test "uses default parameters" do
      data = 1..50 |> Enum.to_list()
      {macd_line, signal_line, histogram} = Indicators.macd(data)

      assert length(macd_line) == 50
      assert length(signal_line) == 50
      assert length(histogram) == 50
    end
  end

  describe "bollinger_bands/3" do
    test "calculates Bollinger Bands correctly" do
      data = [20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34]
      {upper, middle, lower} = Indicators.bollinger_bands(data, 5, 2)

      assert length(upper) == length(data)
      assert length(middle) == length(data)
      assert length(lower) == length(data)

      # Check that upper > middle > lower where values exist
      Enum.zip([upper, middle, lower])
      |> Enum.each(fn {u, m, l} ->
        if u && m && l do
          assert u > m
          assert m > l
        end
      end)
    end

    test "middle band equals SMA" do
      data = [10, 11, 12, 13, 14, 15, 16, 17, 18, 19]
      {_upper, middle, _lower} = Indicators.bollinger_bands(data, 5, 2)
      sma_values = Indicators.sma(data, 5)

      assert middle == sma_values
    end

    test "uses default parameters" do
      data = 1..25 |> Enum.to_list()
      {upper, middle, lower} = Indicators.bollinger_bands(data)

      assert length(upper) == 25
      assert length(middle) == 25
      assert length(lower) == 25
    end
  end

  describe "atr/2" do
    test "calculates ATR correctly" do
      ohlc_data = [
        %{high: 48.70, low: 47.79, close: 48.16},
        %{high: 48.72, low: 48.14, close: 48.61},
        %{high: 48.90, low: 48.39, close: 48.75},
        %{high: 48.87, low: 48.37, close: 48.63},
        %{high: 48.82, low: 48.24, close: 48.74}
      ]

      result = Indicators.atr(ohlc_data, 3)

      assert length(result) == 5
      # First value is always nil
      assert List.first(result) == nil
      # Should have some calculated values
      refute Enum.all?(result, &is_nil/1)
    end

    test "handles single data point" do
      ohlc_data = [%{high: 50, low: 45, close: 48}]
      result = Indicators.atr(ohlc_data, 1)

      assert result == [nil]
    end

    test "uses default period" do
      ohlc_data =
        1..20
        |> Enum.map(fn i ->
          %{high: i + 1, low: i - 1, close: i}
        end)

      result = Indicators.atr(ohlc_data)
      assert length(result) == 20
    end
  end

  describe "crossover?/2" do
    test "detects crossover correctly" do
      # fast_ma crosses above slow_ma
      fast_ma = [10, 11, 12, 13, 14]
      slow_ma = [12, 12, 12, 12, 12]

      assert Indicators.crossover?(fast_ma, slow_ma) == true
    end

    test "returns false when no crossover" do
      fast_ma = [10, 11, 12]
      slow_ma = [13, 13, 13]

      assert Indicators.crossover?(fast_ma, slow_ma) == false
    end

    test "returns false when series1 already above series2" do
      fast_ma = [15, 14, 13]
      slow_ma = [12, 12, 12]

      assert Indicators.crossover?(fast_ma, slow_ma) == false
    end

    test "handles nil values" do
      fast_ma = [nil, 11, 12]
      slow_ma = [13, 13, 13]

      assert Indicators.crossover?(fast_ma, slow_ma) == false
    end

    test "requires at least two values per series" do
      fast_ma = [14]
      slow_ma = [12]

      assert Indicators.crossover?(fast_ma, slow_ma) == false
    end
  end

  describe "crossunder?/2" do
    test "detects crossunder correctly" do
      # fast_ma crosses below slow_ma  
      fast_ma = [14, 13, 12, 11, 10]
      slow_ma = [12, 12, 12, 12, 12]

      assert Indicators.crossunder?(fast_ma, slow_ma) == true
    end

    test "returns false when no crossunder" do
      fast_ma = [15, 14, 13]
      slow_ma = [10, 10, 10]

      assert Indicators.crossunder?(fast_ma, slow_ma) == false
    end

    test "returns false when series1 already below series2" do
      fast_ma = [10, 11, 12]
      slow_ma = [15, 15, 15]

      assert Indicators.crossunder?(fast_ma, slow_ma) == false
    end
  end

  describe "stream compatibility" do
    test "all indicators work with streams" do
      data_stream = 1..100 |> Stream.map(&(&1 * 1.5))

      # Test that indicators work with streams
      sma_result = Indicators.sma(data_stream, 10)
      ema_result = Indicators.ema(data_stream, 10)
      rsi_result = Indicators.rsi(data_stream, 14)

      assert length(sma_result) == 100
      assert length(ema_result) == 100
      assert length(rsi_result) == 100
    end

    test "OHLC indicators work with streams" do
      ohlc_stream =
        1..50
        |> Stream.map(fn i ->
          %{high: i + 1, low: i - 1, close: i}
        end)

      atr_result = Indicators.atr(ohlc_stream, 14)
      assert length(atr_result) == 50
    end
  end
end
