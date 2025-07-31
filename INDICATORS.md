# Indicator Framework Guide

ExPostFacto now includes a comprehensive technical indicator framework that makes it easy to build sophisticated trading strategies.

## Available Indicators

### Simple Moving Average (SMA)
```elixir
prices = [10, 11, 12, 13, 14, 15]
sma_values = ExPostFacto.Indicators.sma(prices, 3)
# => [nil, nil, 11.0, 12.0, 13.0, 14.0]
```

### Exponential Moving Average (EMA)
```elixir
prices = [22.27, 22.19, 22.08, 22.17, 22.18]
ema_values = ExPostFacto.Indicators.ema(prices, 3)
# EMA gives more weight to recent prices
```

### Relative Strength Index (RSI)
```elixir
prices = [44, 44.34, 44.09, 44.15, 43.61, 44.33, 44.83, 45.85, 46.08, 45.89]
rsi_values = ExPostFacto.Indicators.rsi(prices, 14)
# Values range from 0-100, indicating overbought/oversold conditions
```

### MACD (Moving Average Convergence Divergence)
```elixir
prices = [12, 13, 14, 15, 16, 17, 18, 19, 20, 21]
{macd_line, signal_line, histogram} = ExPostFacto.Indicators.macd(prices)
# Returns three series: MACD line, signal line, and histogram
```

### Bollinger Bands
```elixir
prices = [20, 21, 22, 23, 24, 25, 26, 27, 28, 29]
{upper_band, middle_band, lower_band} = ExPostFacto.Indicators.bollinger_bands(prices, 5, 2)
# Returns upper band, middle band (SMA), and lower band
```

### Average True Range (ATR)
```elixir
ohlc_data = [
  %{high: 48.70, low: 47.79, close: 48.16},
  %{high: 48.72, low: 48.14, close: 48.61},
  %{high: 48.90, low: 48.39, close: 48.75}
]
atr_values = ExPostFacto.Indicators.atr(ohlc_data, 14)
# Measures volatility
```

## Crossover Detection

### Basic Crossover
```elixir
fast_ma = [10, 11, 12, 13, 14]
slow_ma = [12, 12, 12, 12, 12]

# Check if fast MA crosses above slow MA
crossover = ExPostFacto.Indicators.crossover?(fast_ma, slow_ma)
# => true

# Check if fast MA crosses below slow MA
crossunder = ExPostFacto.Indicators.crossunder?(fast_ma, slow_ma)
# => false
```

## Using Indicators in Strategies

### Strategy Module Integration
```elixir
defmodule MyMacdStrategy do
  use ExPostFacto.Strategy

  def init(_opts) do
    {:ok, %{price_history: []}}
  end

  def next(state) do
    current_data = data()
    current_price = current_data.close
    
    # Update price history
    price_history = [current_price | state.price_history]
    
    # Calculate MACD using the indicator framework
    {macd_line, signal_line, _histogram} = indicator(:macd, price_history)
    
    # Make trading decisions based on MACD crossover
    if crossover?(macd_line, signal_line) do
      buy()
    elsif crossunder?(macd_line, signal_line) do
      sell()
    end

    {:ok, %{state | price_history: price_history}}
  end
end
```

### Direct Indicator Access
```elixir
# Within a strategy, you can call indicators directly:
sma_20 = indicator(:sma, price_data, 20)
ema_12 = indicator(:ema, price_data, 12)
rsi_14 = indicator(:rsi, price_data, 14)

# MACD with custom parameters
{macd, signal, hist} = indicator(:macd, price_data, {12, 26, 9})

# Bollinger Bands with custom parameters
{upper, middle, lower} = indicator(:bollinger_bands, price_data, {20, 2.5})
```

## Stream Support

All indicators work efficiently with Elixir streams for memory-efficient processing:

```elixir
large_dataset
|> Stream.map(&(&1.close))
|> ExPostFacto.Indicators.sma(20)
|> Stream.filter(&(&1 != nil))
|> Enum.take(100)
```

## Advanced Example Strategy

Here's a comprehensive strategy using multiple indicators:

```elixir
defmodule AdvancedStrategy do
  use ExPostFacto.Strategy
  
  def init(_opts) do
    {:ok, %{price_history: []}}
  end
  
  def next(state) do
    price = data().close
    history = [price | state.price_history] |> Enum.take(100)
    
    # Calculate multiple indicators
    {macd, signal, _} = indicator(:macd, history)
    rsi = indicator(:rsi, history) |> List.first()
    {bb_upper, bb_middle, bb_lower} = indicator(:bollinger_bands, history)
    sma_50 = indicator(:sma, history, 50) |> List.first()
    
    current_price = List.first(history)
    
    # Complex trading logic
    cond do
      # Bullish conditions
      crossover?(macd, signal) and 
      rsi < 70 and 
      current_price <= List.first(bb_lower) * 1.02 ->
        buy()
        
      # Bearish conditions  
      crossunder?(macd, signal) and
      rsi > 30 and
      current_price >= List.first(bb_upper) * 0.98 ->
        sell()
        
      true ->
        :no_action
    end
    
    {:ok, %{state | price_history: history}}
  end
end
```

## Performance Considerations

- Indicators work with streams for memory efficiency
- Keep price history limited to what you need for calculations
- Use `Enum.take/2` to limit historical data size
- All indicators handle `nil` values gracefully
- Crossover functions require at least 2 data points

## Extending the Framework

You can create custom indicators by following the same patterns:

```elixir
defmodule MyCustomIndicator do
  def my_indicator(data, period) do
    data
    |> Stream.with_index()
    |> Stream.map(fn {value, index} ->
      if index + 1 >= period do
        # Your custom calculation here
        calculate_custom_value(data, index, period)
      else
        nil
      end
    end)
    |> Enum.to_list()
  end
end
```

The indicator framework provides a solid foundation for building sophisticated trading strategies with minimal code and maximum flexibility.