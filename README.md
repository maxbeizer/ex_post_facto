# ExPostFacto

**A comprehensive backtesting library for trading strategies written in Elixir.**

> [!IMPORTANT]
> This library is under active, pre 1.0 development. The APIs are not to be considered stable. Calculations may not be correct. See the [LICENSE](LICENSE) but use at your own risk.

ExPostFacto empowers traders and developers to test their trading strategies against historical data with confidence. Built with Elixir's concurrency and fault-tolerance in mind, it provides enterprise-grade backtesting capabilities with an intuitive API.

## 🚀 Why ExPostFacto?

- **🎯 Easy to Use**: Simple API that gets you backtesting in minutes
- **📊 Professional Grade**: Comprehensive statistics and performance metrics
- **🔧 Flexible**: Support for simple functions or advanced strategy behaviours
- **⚡ Fast**: Concurrent optimization and streaming for large datasets
- **🧹 Robust**: Built-in data validation, cleaning, and error handling
- **📈 Complete**: 20+ technical indicators and optimization algorithms

## ✨ Key Features

### Multiple Input Formats

- **CSV files** - Load data directly from CSV files
- **JSON** - Parse JSON market data
- **Lists of maps** - Use runtime data structures
- **Streaming** - Handle large datasets efficiently

### Data Validation & Cleaning

- **Comprehensive OHLCV validation** with detailed error messages
- **Automatic data cleaning** - Remove invalid points, sort by timestamp
- **Enhanced timestamp handling** - Support for multiple date formats
- **Duplicate detection** and removal

### Flexible Strategy Framework

- **Simple MFA functions** for quick prototypes
- **Advanced Strategy behaviour** with state management
- **Built-in helper functions** - `buy()`, `sell()`, `position()`, etc.
- **20+ technical indicators** - SMA, EMA, RSI, MACD, Bollinger Bands, and more

### Performance & Optimization

- **Parameter optimization** with grid search, random search, walk-forward analysis
- **Concurrent processing** for large parameter spaces
- **Memory-efficient streaming** for massive datasets
- **Performance profiling** and bottleneck identification

### Comprehensive Analytics

- **30+ performance metrics** - Sharpe ratio, CAGR, max drawdown, profit factor
- **Trade analysis** - Win rate, best/worst trades, trade duration
- **Risk metrics** - Drawdown analysis, volatility measures
- **Visual data** - Heatmaps for parameter optimization

=======

See [ENHANCED_DATA_HANDLING_EXAMPLES.md](docs/ENHANCED_DATA_HANDLING_EXAMPLES.md) for detailed usage examples.

## LiveBook Integration

ExPostFacto works seamlessly with [LiveBook](https://livebook.dev/) for interactive backtesting and analysis:

```elixir
# In LiveBook, install dependencies:
Mix.install([
  {:ex_post_facto, "~> 0.1.0"},
  {:kino, "~> 0.12.0"},
  {:kino_vega_lite, "~> 0.1.0"}
])

# Run interactive backtests with rich visualizations
{:ok, result} = ExPostFacto.backtest(data, {MyStrategy, :call, []})
```

See [LiveBook Integration Guide](docs/LIVEBOOK_INTEGRATION.md) for comprehensive examples, interactive forms, and visualization techniques.

## 📖 Quick Start

### Installation

Add ExPostFacto to your `mix.exs`:

```elixir
def deps do
  [
    {:ex_post_facto, "~> 0.1.0"}
  ]
end
```

### Your First Backtest

```elixir
# Sample market data
market_data = [
  %{open: 100.0, high: 105.0, low: 98.0, close: 102.0, timestamp: "2023-01-01"},
  %{open: 102.0, high: 108.0, low: 101.0, close: 106.0, timestamp: "2023-01-02"},
  %{open: 106.0, high: 110.0, low: 104.0, close: 108.0, timestamp: "2023-01-03"}
]

# Simple buy-and-hold strategy
{:ok, result} = ExPostFacto.backtest(
  market_data,
  {ExPostFacto.ExampleStrategies.SimpleBuyHold, :call, []},
  starting_balance: 10_000.0
)

# View results
IO.puts("Total return: $#{result.result.total_profit_and_loss}")
IO.puts("Win rate: #{result.result.win_rate}%")
```

### Load Data from CSV

```elixir
# ExPostFacto automatically handles CSV files
{:ok, result} = ExPostFacto.backtest(
  "path/to/market_data.csv",
  {MyStrategy, :call, []},
  starting_balance: 100_000.0
)
```

## 🎯 Strategy Development

### Simple Function Strategy (MFA)

```elixir
defmodule SimpleThresholdStrategy do
  def call(data, _result) do
    if data.close > 105.0, do: :buy, else: :sell
  end
end

{:ok, result} = ExPostFacto.backtest(
  market_data,
  {SimpleThresholdStrategy, :call, []},
  starting_balance: 10_000.0
)
```

### Advanced Strategy Behaviour

```elixir
defmodule MovingAverageStrategy do
  use ExPostFacto.Strategy

  def init(opts) do
    {:ok, %{
      fast_period: Keyword.get(opts, :fast_period, 10),
      slow_period: Keyword.get(opts, :slow_period, 20),
      price_history: []
    }}
  end

  def next(state) do
    current_price = data().close
    price_history = [current_price | state.price_history]

    if length(price_history) >= state.slow_period do
      fast_sma = indicator(:sma, price_history, state.fast_period)
      slow_sma = indicator(:sma, price_history, state.slow_period)

      if List.first(fast_sma) > List.first(slow_sma) do
        buy()
      else
        sell()
      end
    end

    {:ok, %{state | price_history: price_history}}
  end
end

# Run with custom parameters
{:ok, result} = ExPostFacto.backtest(
  market_data,
  {MovingAverageStrategy, [fast_period: 5, slow_period: 15]},
  starting_balance: 10_000.0
)
```

## 📈 Technical Indicators

ExPostFacto includes 20+ built-in technical indicators:

```elixir
# Available indicators
prices = [100, 101, 102, 103, 104, 105]

sma_20 = indicator(:sma, prices, 20)
ema_12 = indicator(:ema, prices, 12)
rsi_14 = indicator(:rsi, prices, 14)
{macd, signal, histogram} = indicator(:macd, prices)
{bb_upper, bb_middle, bb_lower} = indicator(:bollinger_bands, prices)

# Crossover detection
if crossover?(fast_sma, slow_sma) do
  buy()
end
```

## 🎛️ Strategy Optimization

Find optimal parameters automatically:

```elixir
# Grid search optimization
{:ok, result} = ExPostFacto.optimize(
  market_data,
  MovingAverageStrategy,
  [fast_period: 5..15, slow_period: 20..30],
  maximize: :sharpe_ratio
)

IO.puts("Best parameters: #{inspect(result.best_params)}")
IO.puts("Best Sharpe ratio: #{result.best_score}")

# Walk-forward analysis for robust testing
{:ok, result} = ExPostFacto.optimize(
  market_data,
  MovingAverageStrategy,
  [fast_period: 5..15, slow_period: 20..30],
  method: :walk_forward,
  training_window: 252,  # 1 year
  validation_window: 63  # 3 months
)
```

## 🧹 Data Validation & Cleaning

ExPostFacto ensures your data is clean and valid:

```elixir
# Validate data
case ExPostFacto.validate_data(market_data) do
  :ok -> IO.puts("Data is valid!")
  {:error, reason} -> IO.puts("Validation error: #{reason}")
end

# Clean messy data automatically
{:ok, clean_data} = ExPostFacto.clean_data(dirty_data)

# Enhanced error handling
{:ok, result} = ExPostFacto.backtest(
  market_data,
  strategy,
  enhanced_validation: true,
  debug: true
)
```

## 📊 Example Strategies

ExPostFacto includes several example strategies:

```elixir
# Moving Average Crossover
{:ok, result} = ExPostFacto.backtest(
  data,
  {ExPostFacto.ExampleStrategies.SmaStrategy, [fast_period: 10, slow_period: 20]}
)

# RSI Mean Reversion
{:ok, result} = ExPostFacto.backtest(
  data,
  {ExPostFacto.ExampleStrategies.RSIMeanReversionStrategy, [
    rsi_period: 14,
    oversold_threshold: 30,
    overbought_threshold: 70
  ]}
)

# Bollinger Band Strategy
{:ok, result} = ExPostFacto.backtest(
  data,
  {ExPostFacto.ExampleStrategies.BollingerBandStrategy, [period: 20, std_dev: 2.0]}
)

# Breakout Strategy
{:ok, result} = ExPostFacto.backtest(
  data,
  {ExPostFacto.ExampleStrategies.BreakoutStrategy, [
    lookback_period: 20,
    breakout_threshold: 0.02
  ]}
)
```

## 📚 Documentation & Learning

### Complete Documentation

- **[Getting Started Guide](docs/GETTING_STARTED.md)** - Step-by-step introduction
- **[Interactive Tutorial](docs/tutorial.livemd)** - Livebook tutorial with examples
- **[Strategy API Guide](docs/STRATEGY_API.md)** - Comprehensive strategy development
- **[Technical Indicators](docs/INDICATORS.md)** - All available indicators and usage
- **[Best Practices](docs/BEST_PRACTICES.md)** - Guidelines for effective strategies
- **[Migration Guide](docs/MIGRATION_GUIDE.md)** - Moving from other libraries

### Data Handling

- **[Enhanced Data Handling](docs/ENHANCED_DATA_HANDLING_EXAMPLES.md)** - Data formats and validation
- **[Error Handling](docs/ENHANCED_ERROR_HANDLING_SUMMARY.md)** - Debugging and validation

### Advanced Features

- **[Optimization Guide](docs/OPTIMIZATION.md)** - Parameter optimization techniques
- **[Comprehensive Metrics](docs/COMPREHENSIVE_METRICS.md)** - Performance analysis

## 🔧 Advanced Features

### Streaming for Large Datasets

```elixir
# Handle massive datasets efficiently
{:ok, result} = ExPostFacto.backtest_stream(
  "very_large_dataset.csv",
  {MyStrategy, []},
  chunk_size: 1000,
  memory_limit_mb: 100
)
```

### Concurrent Optimization

```elixir
# Leverage all CPU cores for optimization
{:ok, result} = ExPostFacto.optimize(
  data,
  MyStrategy,
  parameter_ranges,
  method: :random_search,
  samples: 1000,
  max_concurrent: System.schedulers_online()
)
```

### Heatmap Visualization

```elixir
# Generate parameter heatmaps
{:ok, optimization_result} = ExPostFacto.optimize(data, MyStrategy, param_ranges)
{:ok, heatmap} = ExPostFacto.heatmap(optimization_result, :param1, :param2)

# Use heatmap data for visualization
IO.inspect(heatmap.scores)  # 2D array of performance scores
```

## 🆚 Comparison with Other Libraries

| Feature               | ExPostFacto  | backtesting.py | Backtrader | QuantConnect |
| --------------------- | ------------ | -------------- | ---------- | ------------ |
| **Language**          | Elixir       | Python         | Python     | C#/Python    |
| **Concurrency**       | ✅ Native    | ❌             | ❌         | ✅           |
| **Memory Efficiency** | ✅ Streaming | ❌             | ❌         | ✅           |
| **Data Validation**   | ✅ Built-in  | ❌             | ❌         | ✅           |
| **Walk-Forward**      | ✅           | ❌             | ✅         | ✅           |
| **Easy Setup**        | ✅           | ✅             | ❌         | ❌           |

## 🤝 Contributing

We welcome contributions! Please see our [contributing guidelines](CONTRIBUTING.MD) and check out the open issues.

## 📄 License

ExPostFacto is released under the MIT License. See LICENSE for details.

## 🙏 Acknowledgments

Inspired by Python's backtesting.py and other excellent backtesting libraries. Built with the power and elegance of Elixir.

---

**Ready to backtest your trading strategies? [Get started now!](docs/GETTING_STARTED.md)** 🚀
