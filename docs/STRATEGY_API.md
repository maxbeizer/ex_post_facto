# Enhanced Strategy API Guide

## Overview

The Enhanced Strategy API provides a more intuitive and powerful way to develop trading strategies for ExPostFacto. Instead of the traditional MFA tuple approach, strategies now implement a behaviour with clear `init/1` and `next/1` callbacks, along with built-in helper functions and access to trading context.

## Key Features

- **Intuitive Callbacks**: Simple `init/1` and `next/1` functions
- **Built-in Helpers**: `buy()`, `sell()`, `close_buy()`, `close_sell()` 
- **Context Access**: `data()`, `equity()`, `position()` functions
- **Indicator Support**: Framework for technical indicators
- **Backward Compatible**: Existing MFA strategies continue to work

## Basic Usage

### 1. Creating a Strategy

```elixir
defmodule MyStrategy do
  use ExPostFacto.Strategy

  def init(opts) do
    # Initialize strategy state
    {:ok, %{}}
  end

  def next(state) do
    # Make trading decisions
    current_price = data().close
    if current_price > 10.0 do
      buy()
    end
    {:ok, state}
  end
end
```

### 2. Running a Backtest

```elixir
# New Strategy behaviour approach
{:ok, result} = ExPostFacto.backtest(
  market_data, 
  {MyStrategy, [param: 10]},
  starting_balance: 10_000.0
)

# Traditional MFA approach (still supported)
{:ok, result} = ExPostFacto.backtest(
  market_data,
  {MyModule, :my_function, []},
  starting_balance: 10_000.0
)
```

## Available Helper Functions

### Trading Actions
- `buy()` - Enter a long position
- `sell()` - Enter a short position  
- `close_buy()` - Close a long position
- `close_sell()` - Close a short position

### Context Access
- `data()` - Get current market data point (OHLC)
- `equity()` - Get current account equity
- `position()` - Get current position (`:long`, `:short`, or `:none`)

### Utilities
- `crossover?(series1, series2)` - Check if series1 crosses above series2
- `indicator(func, data, period)` - Basic indicator calculation

## Example Strategies

### Simple Buy and Hold

```elixir
defmodule SimpleBuyHold do
  use ExPostFacto.Strategy

  def init(opts) do
    max_trades = Keyword.get(opts, :max_trades, 1)
    {:ok, %{trades_made: 0, max_trades: max_trades}}
  end

  def next(state) do
    if state.trades_made < state.max_trades and position() == :none do
      buy()
      {:ok, %{state | trades_made: state.trades_made + 1}}
    else
      {:ok, state}
    end
  end
end
```

### Moving Average Crossover

```elixir
defmodule SmaStrategy do
  use ExPostFacto.Strategy

  def init(opts) do
    fast_period = Keyword.get(opts, :fast_period, 10)
    slow_period = Keyword.get(opts, :slow_period, 20)
    
    {:ok, %{
      fast_period: fast_period,
      slow_period: slow_period,
      price_history: []
    }}
  end

  def next(state) do
    current_price = data().close
    updated_history = [current_price | state.price_history]
    
    fast_sma = calculate_sma(updated_history, state.fast_period)
    slow_sma = calculate_sma(updated_history, state.slow_period)
    
    # Trading logic based on SMA crossover
    make_trading_decision(fast_sma, slow_sma)
    
    {:ok, %{state | price_history: updated_history}}
  end

  defp calculate_sma(prices, period) do
    if length(prices) >= period do
      prices |> Enum.take(period) |> Enum.sum() |> Kernel./(period)
    else
      0.0
    end
  end

  defp make_trading_decision(fast_sma, slow_sma) do
    cond do
      fast_sma > slow_sma and position() != :long ->
        if position() == :short, do: close_sell()
        buy()
      
      fast_sma < slow_sma and position() != :short ->
        if position() == :long, do: close_buy()
        sell()
        
      true -> :ok
    end
  end
end
```

## Migration from MFA Tuples

### Before (MFA Tuple)
```elixir
defmodule OldStrategy do
  def my_strategy(data_point, result) do
    if data_point.close > 10.0 do
      :buy
    else
      :noop
    end
  end
end

# Usage
ExPostFacto.backtest(data, {OldStrategy, :my_strategy, []})
```

### After (Strategy Behaviour)
```elixir
defmodule NewStrategy do
  use ExPostFacto.Strategy

  def init(_opts), do: {:ok, %{}}

  def next(state) do
    if data().close > 10.0 do
      buy()
    end
    {:ok, state}
  end
end

# Usage  
ExPostFacto.backtest(data, {NewStrategy, []})
```

## Advanced Features

### Error Handling
```elixir
def init(opts) do
  case validate_options(opts) do
    :ok -> {:ok, initial_state}
    {:error, reason} -> {:error, reason}
  end
end

def next(state) do
  try do
    # Strategy logic
    {:ok, new_state}
  rescue
    e -> {:error, e}
  end
end
```

### State Management
```elixir
def next(state) do
  # Access and update strategy state
  new_state = %{
    state | 
    trade_count: state.trade_count + 1,
    last_price: data().close
  }
  {:ok, new_state}
end
```

## Benefits

1. **Intuitive**: Clear separation of initialization and execution logic
2. **Stateful**: Easy state management between data points
3. **Contextual**: Built-in access to trading context and position state
4. **Testable**: Easy to unit test individual strategy components
5. **Composable**: Can build complex strategies from simple components
6. **Compatible**: Works alongside existing MFA tuple strategies

## Implementation Notes

- The Strategy behaviour is implemented using Elixir behaviours and callbacks
- StrategyContext uses an Agent for state management during execution
- Helper functions provide a clean API for common trading operations
- The system automatically detects strategy type (MFA vs behaviour) and routes accordingly
- All existing functionality and APIs remain unchanged for backward compatibility