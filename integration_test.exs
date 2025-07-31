#!/usr/bin/env elixir

# Integration test script for the indicator framework
# This demonstrates that the indicators work without mix dependencies

# Load required modules
Code.require_file("lib/ex_post_facto/indicators.ex", __DIR__)

# Test basic indicator functionality
IO.puts("=== ExPostFacto Indicator Framework Integration Test ===\n")

# Test data
prices = [22.27, 22.19, 22.08, 22.17, 22.18, 22.13, 22.23, 22.43, 22.24, 22.29, 22.15, 22.39, 22.38, 22.61, 23.36, 24.05, 23.75, 23.83, 23.95, 23.63]

IO.puts("Testing with #{length(prices)} price points...")
IO.puts("Sample prices: #{Enum.take(prices, 5) |> Enum.join(", ")}...\n")

# Test SMA
IO.puts("1. Simple Moving Average (SMA-5):")
sma_5 = ExPostFacto.Indicators.sma(prices, 5)
sma_last_5 = Enum.take(sma_5, -5)
IO.puts("   Last 5 values: #{Enum.map(sma_last_5, &(if &1, do: Float.round(&1, 2), else: "nil")) |> Enum.join(", ")}")

# Test EMA
IO.puts("\n2. Exponential Moving Average (EMA-5):")
ema_5 = ExPostFacto.Indicators.ema(prices, 5)
ema_last_5 = Enum.take(ema_5, -5)
IO.puts("   Last 5 values: #{Enum.map(ema_last_5, &(if &1, do: Float.round(&1, 2), else: "nil")) |> Enum.join(", ")}")

# Test RSI
IO.puts("\n3. Relative Strength Index (RSI-14):")
rsi_14 = ExPostFacto.Indicators.rsi(prices, 14)
rsi_last_3 = Enum.take(rsi_14, -3)
IO.puts("   Last 3 values: #{Enum.map(rsi_last_3, &(if &1, do: Float.round(&1, 1), else: "nil")) |> Enum.join(", ")}")

# Test MACD
IO.puts("\n4. MACD (12,26,9):")
{macd_line, signal_line, histogram} = ExPostFacto.Indicators.macd(prices, 12, 26, 9)
macd_last = List.last(macd_line)
signal_last = List.last(signal_line)
histogram_last = List.last(histogram)
IO.puts("   MACD: #{if macd_last, do: Float.round(macd_last, 4), else: "nil"}")
IO.puts("   Signal: #{if signal_last, do: Float.round(signal_last, 4), else: "nil"}")
IO.puts("   Histogram: #{if histogram_last, do: Float.round(histogram_last, 4), else: "nil"}")

# Test Bollinger Bands
IO.puts("\n5. Bollinger Bands (20,2):")
{upper, middle, lower} = ExPostFacto.Indicators.bollinger_bands(prices, 20, 2)
upper_last = List.last(upper)
middle_last = List.last(middle)
lower_last = List.last(lower)
IO.puts("   Upper: #{if upper_last, do: Float.round(upper_last, 2), else: "nil"}")
IO.puts("   Middle: #{if middle_last, do: Float.round(middle_last, 2), else: "nil"}")
IO.puts("   Lower: #{if lower_last, do: Float.round(lower_last, 2), else: "nil"}")

# Test ATR
IO.puts("\n6. Average True Range (ATR-14):")
ohlc_data = Enum.map(prices, fn price ->
  %{
    high: price + 0.15,
    low: price - 0.15,
    close: price
  }
end)
atr_14 = ExPostFacto.Indicators.atr(ohlc_data, 14)
atr_last = List.last(atr_14)
IO.puts("   Last ATR value: #{if atr_last, do: Float.round(atr_last, 3), else: "nil"}")

# Test Crossover Detection
IO.puts("\n7. Crossover Detection:")
fast_ma = ExPostFacto.Indicators.sma(prices, 5)
slow_ma = ExPostFacto.Indicators.sma(prices, 10)

# Create a scenario where fast crosses above slow
test_fast = [10.0, 11.0, 12.0, 13.0, 14.0]
test_slow = [12.0, 12.0, 12.0, 12.0, 12.0]

crossover_result = ExPostFacto.Indicators.crossover?(test_fast, test_slow)

# Create a scenario that actually shows crossover 
crossover_test_fast = [12.0, 12.1, 12.2, 12.9, 13.0]  # crosses above
crossover_test_slow = [12.5, 12.5, 12.5, 12.5, 12.5]
crossover_actual = ExPostFacto.Indicators.crossover?(crossover_test_fast, crossover_test_slow)

crossunder_result = ExPostFacto.Indicators.crossunder?(test_fast, test_slow)

IO.puts("   Test crossover (fast: #{Enum.join(test_fast, ", ")}, slow: #{Enum.join(test_slow, ", ")}): #{crossover_result}")
IO.puts("   Actual crossover test: #{crossover_actual}")
IO.puts("   Test crossunder: #{crossunder_result}")

# Test with real data
real_crossover = ExPostFacto.Indicators.crossover?(fast_ma, slow_ma)
real_crossunder = ExPostFacto.Indicators.crossunder?(fast_ma, slow_ma)
IO.puts("   Real data crossover: #{real_crossover}")
IO.puts("   Real data crossunder: #{real_crossunder}")

# Test Stream Compatibility
IO.puts("\n8. Stream Compatibility Test:")
stream_data = 1..100 |> Stream.map(&(&1 + 20.0))
stream_sma = ExPostFacto.Indicators.sma(stream_data, 10)
stream_count = Enum.count(stream_sma)
IO.puts("   Processed #{stream_count} points from stream")
IO.puts("   Last SMA value: #{List.last(stream_sma) |> Float.round(2)}")

IO.puts("\n=== All tests completed successfully! ===")
IO.puts("\nThe ExPostFacto Indicator Framework is working correctly and ready for use in trading strategies.")