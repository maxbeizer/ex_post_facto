# ExPostFacto API Reference

This document provides a comprehensive reference for all ExPostFacto modules, functions, and types.

## Core Modules

### ExPostFacto

The main module providing the primary backtesting functions.

#### Main Functions

**`backtest/3`**
```elixir
@spec backtest(
  data :: [map()] | String.t(),
  strategy :: strategy(),
  options :: keyword()
) :: {:ok, Output.t()} | {:error, String.t()}
```

Run a backtest with the given data and strategy.

**Parameters:**
- `data` - Market data as list of maps, CSV file path, or JSON string
- `strategy` - Either `{Module, :function, args}` or `{Module, opts}` for Strategy behaviour
- `options` - Keyword list of options

**Options:**
- `:starting_balance` - Initial capital (default: 10,000.0)
- `:validate_data` - Enable data validation (default: true)
- `:clean_data` - Enable data cleaning (default: true)
- `:enhanced_validation` - Use enhanced validation system (default: false)
- `:debug` - Enable debug logging (default: false)

**Examples:**
```elixir
# Basic backtest
{:ok, result} = ExPostFacto.backtest(data, {MyStrategy, :call, []})

# With options
{:ok, result} = ExPostFacto.backtest(
  data,
  {MyStrategy, [param: 10]},
  starting_balance: 100_000.0,
  enhanced_validation: true
)
```

**`backtest!/3`**

Same as `backtest/3` but raises `ExPostFacto.BacktestError` on failure.

**`optimize/4`**
```elixir
@spec optimize(
  data :: [map()],
  strategy_module :: atom(),
  param_ranges :: [{atom(), Range.t() | [any()]}],
  opts :: keyword()
) :: {:ok, map()} | {:error, String.t()}
```

Optimize strategy parameters using various methods.

**Parameters:**
- `data` - Market data for optimization
- `strategy_module` - Strategy module implementing ExPostFacto.Strategy
- `param_ranges` - Parameter names and their ranges/values to test
- `opts` - Optimization options

**Options:**
- `:method` - `:grid_search`, `:random_search`, or `:walk_forward` (default: `:grid_search`)
- `:maximize` - Metric to optimize (default: `:sharpe_ratio`)
- `:samples` - Number of samples for random search (default: 100)
- `:max_combinations` - Maximum combinations for grid search (default: 1000)

**Available Metrics:**
- `:sharpe_ratio` - Risk-adjusted return
- `:total_return_pct` - Total percentage return
- `:cagr_pct` - Compound Annual Growth Rate
- `:profit_factor` - Gross profit / gross loss
- `:win_rate` - Percentage of winning trades
- `:max_draw_down_percentage` - Maximum drawdown (minimized)

**Examples:**
```elixir
# Grid search optimization
{:ok, result} = ExPostFacto.optimize(
  data,
  MyStrategy,
  [fast: 5..20, slow: 20..50],
  maximize: :sharpe_ratio
)

# Random search
{:ok, result} = ExPostFacto.optimize(
  data,
  MyStrategy,
  [fast: 5..20, slow: 20..50],
  method: :random_search,
  samples: 200
)
```

**`backtest_stream/3`**
```elixir
@spec backtest_stream(
  data_source :: String.t() | Enumerable.t(),
  strategy :: strategy(),
  options :: keyword()
) :: {:ok, Output.t()} | {:error, String.t()}
```

Memory-efficient backtesting for large datasets using streaming.

**Options:**
- `:chunk_size` - Data points per chunk (default: 1000)
- `:window_size` - Rolling window for strategy context (default: 100)
- `:overlap` - Overlap between chunks (default: 10)
- `:memory_limit_mb` - Memory limit in MB (default: 100)

### ExPostFacto.Strategy

Behaviour module for implementing advanced trading strategies.

#### Callbacks

**`init/1`**
```elixir
@callback init(opts :: keyword()) :: {:ok, state :: any()} | {:error, reason :: any()}
```

Initialize strategy with given options. Return initial state.

**`next/1`**
```elixir
@callback next(state :: any()) :: {:ok, new_state :: any()} | {:error, reason :: any()}
```

Process next data point. Called for each market data point.

#### Helper Functions

Available when using `use ExPostFacto.Strategy`:

**Trading Actions:**
- `buy/0` - Enter long position
- `sell/0` - Enter short position  
- `close_buy/0` - Close long position
- `close_sell/0` - Close short position

**Context Access:**
- `data/0` - Get current market data point
- `equity/0` - Get current account equity
- `position/0` - Get current position (`:none`, `:long`, `:short`)

**Technical Analysis:**
- `indicator/2` - Calculate indicator: `indicator(:sma, prices)`
- `indicator/3` - Calculate with params: `indicator(:sma, prices, 20)`
- `crossover?/2` - Check if series A crosses above series B
- `crossunder?/2` - Check if series A crosses below series B

#### Example Strategy

```elixir
defmodule MySMAStrategy do
  use ExPostFacto.Strategy

  def init(opts) do
    fast = Keyword.get(opts, :fast, 10)
    slow = Keyword.get(opts, :slow, 20)
    {:ok, %{fast: fast, slow: slow, prices: []}}
  end

  def next(state) do
    price = data().close
    prices = [price | state.prices]
    
    if length(prices) >= state.slow do
      fast_sma = indicator(:sma, prices, state.fast) |> List.first()
      slow_sma = indicator(:sma, prices, state.slow) |> List.first()
      
      if fast_sma > slow_sma and position() != :long do
        buy()
      elsif fast_sma < slow_sma and position() != :short do
        sell()
      end
    end
    
    {:ok, %{state | prices: prices}}
  end
end
```

### ExPostFacto.Indicators

Technical indicator calculations.

#### Available Indicators

**Moving Averages:**
- `sma/2` - Simple Moving Average
- `ema/2` - Exponential Moving Average
- `wma/2` - Weighted Moving Average

**Momentum Oscillators:**
- `rsi/2` - Relative Strength Index
- `stochastic/2` - Stochastic Oscillator
- `williams_r/2` - Williams %R

**Trend Indicators:**
- `macd/2` - Moving Average Convergence Divergence
- `adx/2` - Average Directional Index
- `aroon/2` - Aroon Indicator

**Volatility Indicators:**
- `bollinger_bands/2` - Bollinger Bands
- `atr/2` - Average True Range
- `keltner_channels/2` - Keltner Channels

**Volume Indicators:**
- `obv/2` - On-Balance Volume
- `ad_line/2` - Accumulation/Distribution Line

#### Usage

```elixir
# Within a strategy
sma_20 = indicator(:sma, price_history, 20)
rsi_14 = indicator(:rsi, price_history, 14)
{macd, signal, histogram} = indicator(:macd, price_history)
{upper, middle, lower} = indicator(:bollinger_bands, price_history, {20, 2.0})

# Direct usage
alias ExPostFacto.Indicators
sma_values = Indicators.sma(prices, 20)
```

### ExPostFacto.Result

Contains backtesting results and performance statistics.

#### Key Fields

**Trade Statistics:**
- `trades_count` - Total number of trades
- `wins_count` - Number of winning trades
- `win_rate` - Percentage of winning trades
- `total_profit_and_loss` - Total P&L in currency units
- `total_return_percentage` - Total return as percentage

**Trade Analysis:**
- `best_trade_percentage` - Best single trade return
- `worst_trade_percentage` - Worst single trade return
- `average_trade_percentage` - Average trade return
- `trade_pairs` - List of individual trades

**Risk Metrics:**
- `max_draw_down_percentage` - Maximum drawdown
- `average_draw_down_percentage` - Average drawdown
- `max_draw_down_duration` - Longest drawdown period
- `sharpe_ratio` - Risk-adjusted return metric
- `cagr_percentage` - Compound Annual Growth Rate

**Time Analysis:**
- `start_date` - Backtest start date
- `end_date` - Backtest end date
- `total_days` - Total days in backtest
- `max_trade_duration` - Longest trade duration
- `average_trade_duration` - Average trade duration

### ExPostFacto.Optimizer

Parameter optimization functionality.

#### Methods

**`grid_search/4`**

Test all combinations of parameters within specified ranges.

**`random_search/4`**

Randomly sample parameter combinations for faster optimization.

**`walk_forward/4`**

Rolling window optimization for more robust parameter selection.

#### Example

```elixir
# Grid search
{:ok, result} = ExPostFacto.Optimizer.grid_search(
  data,
  MyStrategy,
  [fast: 5..15, slow: 20..30],
  maximize: :sharpe_ratio
)

# Access results
best_params = result.best_params  # %{fast: 10, slow: 25}
best_score = result.best_score    # 1.25
all_results = result.all_results  # All parameter combinations tested
```

### ExPostFacto.Validation

Enhanced data validation and error handling.

#### Functions

**`validate_data/2`**

Comprehensive OHLCV data validation with detailed error messages.

**`validate_strategy/2`**

Validate strategy module and parameters.

**`format_error/1`**

Format validation errors for user-friendly display.

#### Usage

```elixir
# Enhanced validation
case ExPostFacto.backtest(
  data,
  strategy,
  enhanced_validation: true,
  debug: true
) do
  {:ok, result} -> result
  {:error, %ExPostFacto.Validation.ValidationError{} = error} ->
    IO.puts(ExPostFacto.Validation.format_error(error))
end
```

## Data Structures

### Market Data Format

Market data should be provided as maps with OHLCV fields:

```elixir
%{
  open: 100.0,           # Opening price (required)
  high: 105.0,           # High price (required)  
  low: 98.0,             # Low price (required)
  close: 102.0,          # Closing price (required)
  volume: 1_000_000,     # Volume (optional)
  timestamp: "2023-01-01" # Timestamp (optional but recommended)
}
```

**Alternative field names:**
- `o`, `h`, `l`, `c` instead of `open`, `high`, `low`, `close`
- `t` instead of `timestamp`

### CSV Format

Supported CSV formats:

```csv
Date,Open,High,Low,Close,Volume
2023-01-01,100.0,105.0,98.0,102.0,1000000
2023-01-02,102.0,108.0,101.0,106.0,1200000
```

Headers are case-insensitive. Common variations supported:
- `Date`, `Time`, `Timestamp` for date column
- `Adj Close` for adjusted closing price

### Strategy Types

**MFA Tuple:**
```elixir
{Module, :function, args}
```

**Strategy Behaviour:**
```elixir
{Module, opts}  # where Module implements ExPostFacto.Strategy
```

### Actions

Valid trading actions returned by strategies:
- `:buy` - Enter long position
- `:sell` - Enter short position
- `:close_buy` - Close long position  
- `:close_sell` - Close short position

## Error Handling

### Exception Types

- `ExPostFacto.BacktestError` - General backtest errors
- `ExPostFacto.DataValidationError` - Data validation errors (legacy)
- `ExPostFacto.Validation.ValidationError` - Enhanced validation errors
- `ExPostFacto.Validation.StrategyError` - Strategy-specific errors

### Best Practices

1. Always use enhanced validation for development:
   ```elixir
   {:ok, result} = ExPostFacto.backtest(
     data,
     strategy,
     enhanced_validation: true,
     debug: true
   )
   ```

2. Validate data before backtesting:
   ```elixir
   case ExPostFacto.validate_data(data) do
     :ok -> run_backtest(data)
     {:error, reason} -> handle_error(reason)
   end
   ```

3. Handle errors gracefully:
   ```elixir
   case ExPostFacto.backtest(data, strategy) do
     {:ok, result} -> process_result(result)
     {:error, error} -> 
       Logger.error("Backtest failed: #{error}")
       :error
   end
   ```

## Performance Considerations

### Memory Usage

- Use `backtest_stream/3` for large datasets
- Limit price history in strategies to what's needed
- Enable data cleaning to remove invalid points

### Optimization

- Use `:random_search` for large parameter spaces
- Set reasonable `:max_combinations` limits
- Consider `:walk_forward` for robust optimization

### Concurrency

- Optimization automatically uses available CPU cores
- Set `:max_concurrent` to control parallelism
- Streaming processes data in chunks to avoid memory issues

## Examples

See the `lib/ex_post_facto/example_strategies/` directory for complete strategy examples and the `docs/` directory for comprehensive guides and tutorials.