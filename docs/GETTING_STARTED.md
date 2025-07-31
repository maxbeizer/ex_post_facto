# Getting Started with ExPostFacto

ExPostFacto is a comprehensive backtesting library for trading strategies written in Elixir. This guide will help you get up and running quickly.

## What is Backtesting?

Backtesting is the process of testing a trading strategy on historical data to see how it would have performed. ExPostFacto makes this easy by providing:

- 📊 **Multiple data formats** - CSV, JSON, lists of maps
- 🧹 **Data validation and cleaning** - Automatic handling of messy data
- 🚀 **Flexible strategy framework** - Both simple functions and advanced behaviours
- 📈 **Comprehensive statistics** - Detailed performance metrics
- ⚡ **Performance optimization** - Grid search, random search, walk-forward analysis

## Installation

Add ExPostFacto to your `mix.exs` dependencies:

```elixir
def deps do
  [
    {:ex_post_facto, "~> 0.1.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Your First Backtest

Let's start with a simple example using some sample market data:

```elixir
# Define some sample market data
market_data = [
  %{open: 100.0, high: 105.0, low: 98.0, close: 102.0, timestamp: "2023-01-01"},
  %{open: 102.0, high: 108.0, low: 101.0, close: 106.0, timestamp: "2023-01-02"},
  %{open: 106.0, high: 110.0, low: 104.0, close: 108.0, timestamp: "2023-01-03"},
  %{open: 108.0, high: 112.0, low: 107.0, close: 110.0, timestamp: "2023-01-04"},
  %{open: 110.0, high: 115.0, low: 109.0, close: 113.0, timestamp: "2023-01-05"}
]

# Simple buy-and-hold strategy - just buy on the first data point
{:ok, result} = ExPostFacto.backtest(
  market_data,
  {ExPostFacto.ExampleStrategies.SimpleBuyHold, :call, []},
  starting_balance: 10_000.0
)

# View the results
IO.puts("Total return: $#{result.result.total_profit_and_loss}")
IO.puts("Number of trades: #{result.result.trades_count}")
```

## Loading Data from Files

ExPostFacto can automatically load data from CSV files:

```elixir
# Load data from a CSV file
{:ok, result} = ExPostFacto.backtest(
  "path/to/your/market_data.csv",
  {MyStrategy, :call, []},
  starting_balance: 10_000.0
)
```

### CSV Format

Your CSV should have these columns (case-insensitive):
- `Date` or `Timestamp` - The date/time
- `Open` - Opening price
- `High` - Highest price
- `Low` - Lowest price  
- `Close` - Closing price
- `Volume` (optional) - Trading volume

Example:
```csv
Date,Open,High,Low,Close,Volume
2023-01-01,100.0,105.0,98.0,102.0,1000000
2023-01-02,102.0,108.0,101.0,106.0,1200000
```

## Creating Your First Strategy

There are two ways to create strategies in ExPostFacto:

### 1. Simple Function Strategy (MFA Tuple)

```elixir
defmodule MySimpleStrategy do
  def call(current_data, result) do
    # Buy if price is above $100
    if current_data.close > 100.0 do
      :buy
    else
      :sell
    end
  end
end

# Use it in a backtest
{:ok, result} = ExPostFacto.backtest(
  market_data,
  {MySimpleStrategy, :call, []},
  starting_balance: 10_000.0
)
```

### 2. Advanced Strategy Behaviour (Recommended)

```elixir
defmodule MyAdvancedStrategy do
  use ExPostFacto.Strategy

  def init(opts) do
    threshold = Keyword.get(opts, :threshold, 100.0)
    {:ok, %{threshold: threshold}}
  end

  def next(state) do
    current_price = data().close
    
    if current_price > state.threshold do
      buy()
    else
      sell()
    end
    
    {:ok, state}
  end
end

# Use it in a backtest  
{:ok, result} = ExPostFacto.backtest(
  market_data,
  {MyAdvancedStrategy, [threshold: 105.0]},
  starting_balance: 10_000.0
)
```

## Understanding Results

Every backtest returns detailed statistics:

```elixir
{:ok, output} = ExPostFacto.backtest(market_data, strategy)

# Access key metrics
result = output.result

IO.puts("=== Performance Summary ===")
IO.puts("Total P&L: $#{result.total_profit_and_loss}")
IO.puts("Total Return %: #{result.total_return_percentage}%")
IO.puts("Number of Trades: #{result.trades_count}")
IO.puts("Win Rate: #{result.win_rate}%")
IO.puts("Best Trade: #{result.best_trade_percentage}%")
IO.puts("Worst Trade: #{result.worst_trade_percentage}%")
IO.puts("Max Drawdown: #{result.max_draw_down_percentage}%")

# Advanced metrics (if available)
if Map.has_key?(result, :sharpe_ratio) do
  IO.puts("Sharpe Ratio: #{result.sharpe_ratio}")
  IO.puts("CAGR: #{result.cagr_percentage}%")
  IO.puts("Profit Factor: #{result.profit_factor}")
end
```

## Data Validation and Cleaning

ExPostFacto automatically validates and cleans your data:

```elixir
# Validate data manually
case ExPostFacto.validate_data(market_data) do
  :ok -> IO.puts("Data is valid!")
  {:error, reason} -> IO.puts("Validation error: #{reason}")
end

# Clean messy data
{:ok, clean_data} = ExPostFacto.clean_data(dirty_data)

# Control validation and cleaning in backtests
{:ok, result} = ExPostFacto.backtest(
  market_data,
  strategy,
  validate_data: true,   # Enable validation (default: true)
  clean_data: true       # Enable cleaning (default: true)
)
```

## Error Handling

ExPostFacto provides detailed error messages to help you debug issues:

```elixir
# Enhanced error handling
case ExPostFacto.backtest(data, strategy, enhanced_validation: true) do
  {:ok, output} -> 
    output
  {:error, error} -> 
    IO.puts("Backtest failed: #{error}")
    :error
end
```

## Next Steps

Now that you have the basics, explore these advanced features:

1. **[Strategy Development](STRATEGY_API.md)** - Learn about the advanced Strategy behaviour
2. **[Technical Indicators](INDICATORS.md)** - Use built-in indicators in your strategies  
3. **[Strategy Optimization](OPTIMIZATION.md)** - Find optimal parameters for your strategies
4. **[Best Practices](BEST_PRACTICES.md)** - Guidelines for effective strategy development
5. **[Migration Guide](MIGRATION_GUIDE.md)** - Moving from other backtesting libraries

## Common Issues

### "Module not found" errors
Make sure your strategy module is compiled and available. Use `iex -S mix` to test interactively.

### Data validation errors
Check that your OHLC data has valid relationships (high >= low, open/close between high/low).

### Empty results
Ensure your strategy is actually generating trading signals. Use debug mode to trace execution:

```elixir
{:ok, result} = ExPostFacto.backtest(
  data, 
  strategy, 
  enhanced_validation: true,
  debug: true
)
```

## Example Strategies

ExPostFacto includes several example strategies to get you started:

```elixir
# Simple moving average crossover
{:ok, result} = ExPostFacto.backtest(
  data,
  {ExPostFacto.ExampleStrategies.SmaStrategy, [fast_period: 10, slow_period: 20]}
)

# MACD strategy
{:ok, result} = ExPostFacto.backtest(
  data,
  {ExPostFacto.ExampleStrategies.AdvancedMacdStrategy, []}
)

# Buy and hold
{:ok, result} = ExPostFacto.backtest(
  data,
  {ExPostFacto.ExampleStrategies.SimpleBuyHold, :call, []}
)
```

Happy backtesting! 🚀