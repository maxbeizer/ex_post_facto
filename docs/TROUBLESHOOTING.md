# ExPostFacto Troubleshooting Guide

This guide helps you diagnose and fix common issues when using ExPostFacto.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Data Problems](#data-problems)
- [Strategy Development Issues](#strategy-development-issues)
- [Performance Problems](#performance-problems)
- [Validation Errors](#validation-errors)
- [Common Error Messages](#common-error-messages)
- [Debugging Tips](#debugging-tips)

## Installation Issues

### Problem: Mix dependencies won't resolve

**Error:**
```
** (Mix) Could not resolve dependency :ex_post_facto
```

**Solutions:**
1. Check your `mix.exs` dependency specification:
   ```elixir
   {:ex_post_facto, "~> 0.1.0"}
   ```

2. Clear dependency cache:
   ```bash
   mix deps.clean --all
   mix deps.get
   ```

3. Check Elixir/OTP version compatibility:
   ```bash
   elixir --version
   ```

### Problem: Compilation errors

**Error:**
```
** (CompileError) lib/my_strategy.ex:5: undefined function buy/0
```

**Solution:**
Make sure you're using the Strategy behaviour correctly:
```elixir
defmodule MyStrategy do
  use ExPostFacto.Strategy  # This imports buy/0, sell/0, etc.
  
  def init(_opts), do: {:ok, %{}}
  def next(state), do: {:ok, state}
end
```

## Data Problems

### Problem: "Data cannot be empty" error

**Cause:** Your data list is empty or becomes empty after cleaning.

**Solutions:**
1. Check your data source:
   ```elixir
   IO.inspect(length(market_data), label: "Data length")
   ```

2. Verify data format:
   ```elixir
   IO.inspect(hd(market_data), label: "First data point")
   ```

3. Check if data cleaning removes all points:
   ```elixir
   {:ok, cleaned} = ExPostFacto.clean_data(market_data)
   IO.puts("Original: #{length(market_data)}, Cleaned: #{length(cleaned)}")
   ```

### Problem: CSV file loading fails

**Error:**
```
{:error, "failed to load data: failed to read file: enoent"}
```

**Solutions:**
1. Check file path:
   ```elixir
   File.exists?("path/to/data.csv")
   ```

2. Use absolute paths:
   ```elixir
   path = Path.expand("data/market_data.csv")
   {:ok, result} = ExPostFacto.backtest(path, strategy)
   ```

3. Verify CSV format:
   ```csv
   Date,Open,High,Low,Close,Volume
   2023-01-01,100.0,105.0,98.0,102.0,1000000
   ```

### Problem: Data validation errors

**Error:**
```
{:error, "data point 5: invalid OHLC data: high (95.0) must be >= low (98.0)"}
```

**Solutions:**
1. Clean data before validation:
   ```elixir
   {:ok, clean_data} = ExPostFacto.clean_data(dirty_data)
   {:ok, result} = ExPostFacto.backtest(clean_data, strategy)
   ```

2. Fix data manually:
   ```elixir
   fixed_data = Enum.map(data, fn point ->
     %{point | 
       high: max(point.high, max(point.open, point.close)),
       low: min(point.low, min(point.open, point.close))
     }
   end)
   ```

3. Skip validation (not recommended):
   ```elixir
   {:ok, result} = ExPostFacto.backtest(data, strategy, validate_data: false)
   ```

## Strategy Development Issues

### Problem: Strategy never generates trades

**Symptoms:** `trades_count: 0` in results.

**Debugging steps:**
1. Enable debug mode:
   ```elixir
   {:ok, result} = ExPostFacto.backtest(
     data, strategy,
     enhanced_validation: true,
     debug: true
   )
   ```

2. Add logging to your strategy:
   ```elixir
   def next(state) do
     current_price = data().close
     IO.puts("Current price: #{current_price}")
     
     if current_price > 100 do
       IO.puts("Buy condition met!")
       buy()
     end
     
     {:ok, state}
   end
   ```

3. Check data availability:
   ```elixir
   def next(state) do
     if length(state.price_history) < 20 do
       IO.puts("Not enough data yet: #{length(state.price_history)}")
     else
       # Your strategy logic
     end
     {:ok, state}
   end
   ```

### Problem: Strategy crashes during execution

**Error:**
```
** (FunctionClauseError) no function clause matching in MyStrategy.next/1
```

**Solutions:**
1. Always return proper tuple from `next/1`:
   ```elixir
   def next(state) do
     # Your logic here
     {:ok, state}  # Always return this format
   end
   ```

2. Handle all possible states:
   ```elixir
   def next(state) do
     case calculate_signal(state) do
       {:ok, :buy} -> buy()
       {:ok, :sell} -> sell()
       {:error, _reason} -> :ok  # Handle errors gracefully
     end
     
     {:ok, state}
   end
   ```

3. Use pattern matching safely:
   ```elixir
   def next(state) do
     case Map.get(state, :price_history, []) do
       [] -> :ok  # No history yet
       prices when length(prices) >= 10 -> 
         # Your logic
       _ -> :ok  # Not enough data
     end
     
     {:ok, state}
   end
   ```

### Problem: Indicators return nil or unexpected values

**Cause:** Insufficient data for indicator calculation.

**Solutions:**
1. Check data length requirements:
   ```elixir
   def next(state) do
     price_history = [data().close | state.price_history]
     
     if length(price_history) >= 20 do  # Ensure enough data
       sma = indicator(:sma, price_history, 20)
       current_sma = List.first(sma)
       
       if current_sma do  # Check for nil
         # Use indicator value
       end
     end
     
     {:ok, %{state | price_history: price_history}}
   end
   ```

2. Handle edge cases:
   ```elixir
   def safe_indicator(type, data, params) do
     case indicator(type, data, params) do
       [nil | _] -> nil
       [value | _] when is_number(value) -> value
       _ -> nil
     end
   end
   ```

## Performance Problems

### Problem: Backtests are very slow

**Solutions:**
1. Limit price history:
   ```elixir
   def next(state) do
     max_history = 100  # Only keep what you need
     price_history = 
       [data().close | state.price_history]
       |> Enum.take(max_history)
     
     {:ok, %{state | price_history: price_history}}
   end
   ```

2. Use streaming for large datasets:
   ```elixir
   {:ok, result} = ExPostFacto.backtest_stream(
     "large_file.csv",
     strategy,
     chunk_size: 1000
   )
   ```

3. Optimize indicator calculations:
   ```elixir
   # Bad: Recalculate every time
   def next(state) do
     sma = indicator(:sma, state.price_history, 20)
     # ...
   end
   
   # Good: Cache calculations
   def next(state) do
     state = maybe_update_sma(state)
     # Use cached state.sma_value
   end
   ```

### Problem: Optimization takes too long

**Solutions:**
1. Reduce parameter ranges:
   ```elixir
   # Instead of large ranges
   [fast: 5..50, slow: 20..200]
   
   # Use smaller, focused ranges
   [fast: 8..12, slow: 18..22]
   ```

2. Use random search for large spaces:
   ```elixir
   {:ok, result} = ExPostFacto.optimize(
     data, strategy,
     param_ranges,
     method: :random_search,
     samples: 100
   )
   ```

3. Set reasonable limits:
   ```elixir
   {:ok, result} = ExPostFacto.optimize(
     data, strategy,
     param_ranges,
     max_combinations: 500
   )
   ```

## Validation Errors

### Problem: Enhanced validation errors

**Error:**
```
{:error, %ExPostFacto.Validation.ValidationError{
  message: "Strategy validation failed",
  context: %{...}
}}
```

**Solutions:**
1. Format errors for readability:
   ```elixir
   case ExPostFacto.backtest(data, strategy, enhanced_validation: true) do
     {:ok, result} -> result
     {:error, %ExPostFacto.Validation.ValidationError{} = error} ->
       IO.puts(ExPostFacto.Validation.format_error(error))
       :error
   end
   ```

2. Use debug mode:
   ```elixir
   {:ok, result} = ExPostFacto.backtest(
     data, strategy,
     enhanced_validation: true,
     debug: true
   )
   ```

## Common Error Messages

### "Module not found" or "Function not exported"

**Error:**
```
** (UndefinedFunctionError) function MyStrategy.init/1 is undefined
```

**Solution:**
Ensure your strategy module implements the required callbacks:
```elixir
defmodule MyStrategy do
  use ExPostFacto.Strategy
  
  def init(opts) do
    {:ok, %{}}
  end
  
  def next(state) do
    {:ok, state}
  end
end
```

### "Invalid strategy format"

**Cause:** Incorrect strategy specification.

**Solutions:**
```elixir
# Correct formats:
{MyStrategy, :call, []}           # MFA tuple
{MyStrategy, [param: value]}      # Strategy behaviour

# Incorrect:
MyStrategy                        # Just module name
{MyStrategy}                      # Incomplete tuple
```

### "Position function not available"

**Error:**
```
** (UndefinedFunctionError) function :position not found
```

**Solution:**
Use `position()` inside Strategy behaviour context:
```elixir
defmodule MyStrategy do
  use ExPostFacto.Strategy
  
  def next(state) do
    current_pos = position()  # This works here
    # ...
  end
end

# Not in MFA functions:
defmodule MyMFAStrategy do
  def call(data, result) do
    # position() not available here
    # Use result.current_position instead
  end
end
```

## Debugging Tips

### Enable Enhanced Logging

```elixir
# Full debugging
{:ok, result} = ExPostFacto.backtest(
  data, strategy,
  enhanced_validation: true,
  debug: true,
  warnings: true
)
```

### Add Temporary Logging

```elixir
def next(state) do
  IO.inspect(data(), label: "Current data")
  IO.inspect(position(), label: "Current position")
  IO.inspect(equity(), label: "Current equity")
  
  # Your strategy logic
  {:ok, state}
end
```

### Test with Minimal Data

```elixir
# Create simple test data
test_data = [
  %{open: 100, high: 105, low: 98, close: 102},
  %{open: 102, high: 108, low: 101, close: 106},
  %{open: 106, high: 110, low: 104, close: 108}
]

{:ok, result} = ExPostFacto.backtest(test_data, strategy)
```

### Validate Strategy Logic Separately

```elixir
# Test your strategy logic outside of backtesting
defmodule StrategyTester do
  def test_logic do
    state = %{threshold: 100}
    data = %{close: 105}
    
    # Mock the data() function
    result = if data.close > state.threshold, do: :buy, else: :sell
    IO.puts("Signal: #{result}")
  end
end
```

### Use IEx for Interactive Testing

```elixir
# In IEx
iex> data = [%{open: 100, high: 105, low: 98, close: 102}]
iex> {:ok, result} = ExPostFacto.backtest(data, {MyStrategy, []})
iex> IO.inspect(result.result)
```

### Profile Performance

```elixir
# Time your backtests
{time, {:ok, result}} = :timer.tc(fn ->
  ExPostFacto.backtest(data, strategy)
end)

IO.puts("Backtest took #{time / 1000} ms")
```

### Check Memory Usage

```elixir
# Monitor memory during development
before = :erlang.memory(:total)
{:ok, result} = ExPostFacto.backtest(data, strategy)
after_mem = :erlang.memory(:total)

IO.puts("Memory used: #{(after_mem - before) / 1024 / 1024} MB")
```

## Getting Help

If you're still having issues:

1. **Check the logs** - Look for warning messages that might indicate problems
2. **Review examples** - Compare your code with working examples in `lib/ex_post_facto/example_strategies/`
3. **Read the docs** - Check the API reference and guides in the `docs/` directory
4. **Create minimal reproduction** - Simplify your strategy to isolate the issue
5. **Open an issue** - If you've found a bug, please report it on GitHub

## Common Gotchas

1. **Strategy state must be immutable** - Always return updated state from `next/1`
2. **Indicator data order** - Most recent data should be first in the list
3. **Position management** - `buy()` enters long, `close_buy()` exits long
4. **Data requirements** - Some indicators need minimum data points to work
5. **Memory management** - Limit historical data to what you actually need

Remember: When in doubt, enable debug mode and add logging to understand what's happening in your strategy!

## Performance Checklist

- [ ] Limit price history to reasonable size (< 200 points usually sufficient)
- [ ] Cache expensive calculations when possible
- [ ] Use appropriate optimization methods for your parameter space
- [ ] Consider streaming for very large datasets
- [ ] Profile memory usage for long-running strategies
- [ ] Use concurrent optimization when testing many parameters

Happy debugging! 🐛➡️✨