# Best Practices Guide for ExPostFacto

This guide covers best practices for developing effective trading strategies and conducting reliable backtests with ExPostFacto.

## Table of Contents

- [Strategy Development](#strategy-development)
- [Data Management](#data-management)
- [Backtesting Methodology](#backtesting-methodology)
- [Performance Optimization](#performance-optimization)
- [Risk Management](#risk-management)
- [Testing and Validation](#testing-and-validation)
- [Production Considerations](#production-considerations)

## Strategy Development

### Choose the Right Strategy Pattern

**Use MFA tuples for simple strategies:**
```elixir
defmodule SimpleThresholdStrategy do
  def call(data, _result) do
    if data.close > 100.0, do: :buy, else: :sell
  end
end
```

**Use Strategy behaviour for complex strategies:**
```elixir
defmodule ComplexMacdStrategy do
  use ExPostFacto.Strategy
  
  def init(opts) do
    {:ok, %{
      fast_period: Keyword.get(opts, :fast_period, 12),
      slow_period: Keyword.get(opts, :slow_period, 26),
      signal_period: Keyword.get(opts, :signal_period, 9),
      price_history: []
    }}
  end
  
  def next(state) do
    # Complex logic with state management
    {:ok, updated_state}
  end
end
```

### Strategy Design Principles

#### 1. Keep It Simple
- Start with simple strategies and add complexity gradually
- Each strategy should have a clear, testable hypothesis
- Avoid over-optimization (curve fitting)

#### 2. State Management
```elixir
def next(state) do
  # Good: Update state immutably
  new_state = %{state | price_history: [current_price | state.price_history]}
  
  # Bad: Mutating external state
  # Agent.update(:my_agent, fn prices -> [current_price | prices] end)
  
  {:ok, new_state}
end
```

#### 3. Use Technical Indicators Effectively
```elixir
def next(state) do
  prices = [data().close | state.price_history]
  
  # Calculate indicators
  sma_20 = indicator(:sma, prices, 20)
  rsi_14 = indicator(:rsi, prices, 14)
  {macd, signal, _} = indicator(:macd, prices)
  
  # Combine multiple signals
  bullish = rsi_14 < 30 and List.first(macd) > List.first(signal)
  
  if bullish and position() != :long do
    buy()
  end
  
  {:ok, %{state | price_history: prices}}
end
```

#### 4. Handle Edge Cases
```elixir
def next(state) do
  # Check for sufficient data
  if length(state.price_history) < state.required_periods do
    {:ok, state}  # Don't trade without enough data
  else
    # Your trading logic here
    make_trading_decision(state)
  end
end
```

## Data Management

### Data Quality Standards

#### 1. Validate Your Data
```elixir
# Always validate before backtesting
case ExPostFacto.validate_data(market_data) do
  :ok -> 
    run_backtest(market_data)
  {:error, reason} -> 
    IO.puts("Data validation failed: #{reason}")
    fix_data_issues(market_data)
end
```

#### 2. Clean Messy Data
```elixir
# Enable automatic cleaning
{:ok, result} = ExPostFacto.backtest(
  market_data,
  strategy,
  clean_data: true,      # Removes invalid points
  validate_data: true    # Validates OHLC relationships
)
```

#### 3. Handle Missing Data Appropriately
```elixir
# Fill gaps in data
def fill_missing_data(data) do
  data
  |> Enum.sort_by(& &1.timestamp)
  |> fill_price_gaps()
  |> remove_duplicate_timestamps()
end

defp fill_price_gaps(data) do
  # Implementation for forward-fill or interpolation
  Enum.map_reduce(data, nil, fn point, prev ->
    case point do
      %{close: nil} when not is_nil(prev) ->
        {%{point | close: prev.close}, point}
      _ ->
        {point, point}
    end
  end)
  |> elem(0)
end
```

### Data Sources and Formats

#### Recommended CSV Format
```csv
Date,Open,High,Low,Close,Volume
2023-01-01,100.00,105.00,98.00,102.00,1000000
2023-01-02,102.00,108.00,101.00,106.00,1200000
```

#### Alternative Formats Supported
```elixir
# Map format (runtime data)
data = [
  %{open: 100.0, high: 105.0, low: 98.0, close: 102.0, timestamp: ~D[2023-01-01]},
  %{open: 102.0, high: 108.0, low: 101.0, close: 106.0, timestamp: ~D[2023-01-02]}
]

# Short notation
data = [
  %{o: 100.0, h: 105.0, l: 98.0, c: 102.0},
  %{o: 102.0, h: 108.0, l: 101.0, c: 106.0}
]
```

## Backtesting Methodology

### Avoid Common Pitfalls

#### 1. Look-Ahead Bias
```elixir
# Bad: Using future data
def bad_strategy(data, result) do
  future_prices = get_next_n_prices(data, 5)  # DON'T DO THIS
  if will_price_increase?(future_prices), do: :buy, else: :sell
end

# Good: Only use current and historical data
def good_strategy(data, result) do
  if data.close > get_sma(result.data_points, 20), do: :buy, else: :sell
end
```

#### 2. Survivorship Bias
- Include delisted/failed assets in your data
- Test on diverse market conditions
- Don't just use successful assets

#### 3. Overfitting
```elixir
# Bad: Too many parameters
{:ok, result} = ExPostFacto.optimize(
  data, MyStrategy,
  [
    short_ma: 1..50, long_ma: 51..200, rsi_period: 5..30,
    rsi_upper: 60..90, rsi_lower: 10..40, stop_loss: 0.01..0.20
  ]
)

# Good: Fewer, meaningful parameters
{:ok, result} = ExPostFacto.optimize(
  data, MyStrategy,
  [fast_period: 5..15, slow_period: 20..40]
)
```

### Walk-Forward Analysis
```elixir
# Use walk-forward analysis for robust testing
{:ok, result} = ExPostFacto.optimize(
  data, MyStrategy,
  [fast_period: 5..15, slow_period: 20..40],
  method: :walk_forward,
  training_window: 252,  # 1 year
  validation_window: 63, # 3 months
  step_size: 21          # 1 month
)
```

### Out-of-Sample Testing
```elixir
# Split data for proper validation
{training_data, test_data} = split_data(full_data, 0.8)

# Optimize on training data
{:ok, optimization_result} = ExPostFacto.optimize(
  training_data, MyStrategy,
  parameter_ranges
)

# Test best parameters on unseen data
{:ok, final_result} = ExPostFacto.backtest(
  test_data,
  {MyStrategy, optimization_result.best_params}
)
```

## Performance Optimization

### Efficient Strategy Implementation

#### 1. Minimize Calculations
```elixir
def next(state) do
  # Good: Only calculate when needed
  if length(state.price_history) >= state.ma_period do
    sma = calculate_sma(state.price_history, state.ma_period)
    make_decision(sma, state)
  else
    {:ok, state}
  end
end

# Bad: Calculate every time
def next(state) do
  sma = calculate_sma(state.price_history, state.ma_period)  # May be unnecessary
  make_decision(sma, state)
end
```

#### 2. Use Built-in Indicators
```elixir
# Good: Use optimized built-in indicators
sma_values = indicator(:sma, prices, 20)
macd_values = indicator(:macd, prices)

# Less efficient: Custom implementation
def slow_sma(prices, period) do
  Enum.map(0..(length(prices) - 1), fn i ->
    if i >= period - 1 do
      prices
      |> Enum.slice((i - period + 1)..i)
      |> Enum.sum()
      |> Kernel./(period)
    else
      nil
    end
  end)
end
```

#### 3. Parallel Optimization
```elixir
# Use concurrent optimization for large parameter spaces
{:ok, result} = ExPostFacto.optimize(
  data, MyStrategy,
  parameter_ranges,
  method: :random_search,
  samples: 1000,
  max_concurrent: System.schedulers_online()
)
```

### Memory Management

#### 1. Limit Historical Data
```elixir
def next(state) do
  # Keep only what you need
  max_history = max(state.ma_period, state.rsi_period) + 10
  
  updated_history = 
    [data().close | state.price_history]
    |> Enum.take(max_history)
  
  {:ok, %{state | price_history: updated_history}}
end
```

#### 2. Stream Large Datasets
```elixir
# For very large datasets
{:ok, result} = ExPostFacto.backtest_stream(
  "very_large_file.csv",
  strategy,
  chunk_size: 1000,
  memory_limit_mb: 100
)
```

## Risk Management

### Position Sizing
```elixir
defmodule RiskManagedStrategy do
  use ExPostFacto.Strategy
  
  def init(opts) do
    {:ok, %{
      max_position_size: Keyword.get(opts, :max_position_size, 0.1),  # 10% of equity
      stop_loss_pct: Keyword.get(opts, :stop_loss, 0.05)             # 5% stop loss
    }}
  end
  
  def next(state) do
    if should_buy?(state) do
      # Calculate position size based on risk
      equity = equity()
      position_size = min(equity * state.max_position_size, calculate_kelly_size(state))
      
      # Use custom order sizing (if implemented)
      buy()  # Or buy(position_size) if position sizing is available
    end
    
    {:ok, state}
  end
end
```

### Stop Loss Implementation
```elixir
def next(state) do
  current_position = position()
  
  case current_position do
    :long ->
      if stop_loss_triggered?(state) do
        close_buy()
      end
    :short ->
      if stop_loss_triggered?(state) do
        close_sell()
      end
    _ ->
      :ok
  end
  
  {:ok, state}
end

defp stop_loss_triggered?(state) do
  # Implement your stop loss logic
  current_price = data().close
  entry_price = get_entry_price(state)
  loss_pct = (entry_price - current_price) / entry_price
  
  loss_pct > state.stop_loss_pct
end
```

## Testing and Validation

### Unit Testing Strategies
```elixir
defmodule MyStrategyTest do
  use ExUnit.Case
  
  test "strategy generates buy signal when conditions are met" do
    state = %{threshold: 100.0}
    data = %{close: 105.0}
    
    # Mock the data() function
    :meck.new(ExPostFacto.Strategy, [:passthrough])
    :meck.expect(ExPostFacto.Strategy, :data, fn -> data end)
    
    result = MyStrategy.next(state)
    
    assert {:ok, _} = result
    # Verify buy signal was generated
    
    :meck.unload(ExPostFacto.Strategy)
  end
end
```

### Integration Testing
```elixir
defmodule BacktestIntegrationTest do
  use ExUnit.Case
  
  test "complete backtest with real data" do
    market_data = load_test_data("test/fixtures/sample_data.csv")
    
    {:ok, result} = ExPostFacto.backtest(
      market_data,
      {MyStrategy, [threshold: 100.0]},
      starting_balance: 10_000.0
    )
    
    assert result.result.trades_count > 0
    assert is_number(result.result.total_profit_and_loss)
  end
end
```

### Validation Checklist

- [ ] Strategy logic is tested in isolation
- [ ] Backtest produces reasonable number of trades
- [ ] Results are consistent across multiple runs with same data
- [ ] Strategy performs reasonably on different market conditions
- [ ] Out-of-sample testing shows similar performance to in-sample
- [ ] Walk-forward analysis validates strategy robustness

## Production Considerations

### Monitoring and Alerting
```elixir
def next(state) do
  result = make_trading_decision(state)
  
  # Log important events
  if significant_event?(result) do
    Logger.info("Strategy event: #{inspect(result)}")
  end
  
  # Monitor for anomalies
  if anomaly_detected?(result, state) do
    send_alert("Strategy anomaly detected")
  end
  
  result
end
```

### Configuration Management
```elixir
# Use configuration files for parameters
config = Application.get_env(:my_app, :strategy_config)

{:ok, result} = ExPostFacto.backtest(
  data,
  {MyStrategy, config.parameters},
  starting_balance: config.starting_balance
)
```

### Error Handling
```elixir
def run_backtest_with_retry(data, strategy, max_retries \\ 3) do
  case ExPostFacto.backtest(data, strategy, enhanced_validation: true) do
    {:ok, result} -> 
      {:ok, result}
    {:error, error} when max_retries > 0 ->
      Logger.warning("Backtest failed, retrying: #{inspect(error)}")
      :timer.sleep(1000)
      run_backtest_with_retry(data, strategy, max_retries - 1)
    {:error, error} ->
      Logger.error("Backtest failed after retries: #{inspect(error)}")
      {:error, error}
  end
end
```

## Summary

Following these best practices will help you:

1. **Develop robust strategies** that work in real market conditions
2. **Avoid common backtesting pitfalls** that lead to false confidence
3. **Optimize performance** for large-scale testing
4. **Manage risk** appropriately in your strategies
5. **Test thoroughly** before deploying strategies
6. **Monitor effectively** in production environments

Remember: The goal is not to create the most complex strategy, but to find simple, robust approaches that work consistently across different market conditions.