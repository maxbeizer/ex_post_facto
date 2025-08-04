# LiveBook Integration Guide

## Overview

[LiveBook](https://livebook.dev/) is Elixir's interactive and collaborative code notebook for data science, machine learning, and exploratory programming. This guide demonstrates how to integrate ExPostFacto with LiveBook to create interactive trading strategy backtesting and analysis workflows.

## Key Benefits

- **Interactive Development**: Test and refine trading strategies in real-time
- **Data Visualization**: Rich charts and graphs using VegaLite and Kino
- **Collaborative Analysis**: Share notebooks with team members
- **Rapid Prototyping**: Quick iteration on strategy ideas
- **Documentation**: Combine code, results, and explanations in one place

## Prerequisites

Before starting, ensure you have:

- Elixir 1.14+ installed
- LiveBook installed and running
- Basic understanding of Elixir and trading concepts

## Installation

### Option 1: Using LiveBook Desktop

1. Download and install [LiveBook Desktop](https://livebook.dev/)
2. Create a new notebook
3. Add ExPostFacto as a dependency in the setup section:

```elixir
Mix.install([
  {:ex_post_facto, "~> 0.2.0"},
  {:kino, "~> 0.12.0"},
  {:kino_vega_lite, "~> 0.1.0"}
])
```

### Option 2: Using LiveBook Server

If running LiveBook as a server:

```bash
# Install LiveBook
mix escript.install hex livebook

# Start LiveBook
livebook server
```

Then add dependencies in your notebook as shown above.

## Quick Start Example

### Basic Backtesting in LiveBook

```elixir
# Cell 1: Setup and Dependencies
Mix.install([
  {:ex_post_facto, "~> 0.2.0"},
  {:kino, "~> 0.12.0"},
  {:kino_vega_lite, "~> 0.1.0"}
])

alias VegaLite, as: Vl
```

```elixir
# Cell 2: Sample Data Generation
defmodule SampleData do
  def generate_ohlc(days \\ 100, base_price \\ 100.0) do
    Enum.reduce(1..days, [], fn day, acc ->
      prev_close = if acc == [], do: base_price, else: hd(acc).close

      # Generate realistic OHLC data with some randomness
      open = prev_close + (:rand.uniform() - 0.5) * 2
      close = open + (:rand.uniform() - 0.5) * 3
      high = max(open, close) + :rand.uniform() * 2
      low = min(open, close) - :rand.uniform() * 2

      point = %{
        open: Float.round(open, 2),
        high: Float.round(high, 2),
        low: Float.round(low, 2),
        close: Float.round(close, 2),
        volume: :rand.uniform(1000000) + 500000,
        timestamp: Date.add(~D[2023-01-01], day - 1) |> Date.to_string()
      }

      [point | acc]
    end) |> Enum.reverse()
  end
end

# Generate 100 days of sample market data
market_data = SampleData.generate_ohlc(100)

IO.puts("Generated #{length(market_data)} data points")
IO.inspect(Enum.take(market_data, 3), label: "Sample data")
```

```elixir
# Cell 3: Simple Moving Average Strategy
defmodule SMAStrategy do
  @doc "Simple Moving Average Crossover Strategy"
  def call(%{close: price}, %{data_points: data_points, is_position_open: is_position_open}) do
    # Get recent prices for moving averages
    recent_prices = [price | Enum.map(data_points, & &1.datum.close)]

    case length(recent_prices) do
      len when len < 20 ->
        :noop  # Not enough data
      _ ->
        # Calculate 10-day and 20-day simple moving averages
        sma_10 = recent_prices |> Enum.take(10) |> Enum.sum() |> Kernel./(10)
        sma_20 = recent_prices |> Enum.take(20) |> Enum.sum() |> Kernel./(20)

        cond do
          !is_position_open && sma_10 > sma_20 -> :buy    # Golden cross - buy signal
          is_position_open && sma_10 < sma_20 -> :close_buy  # Death cross - sell signal
          true -> :noop
        end
    end
  end
end
```

```elixir
# Cell 4: Run Backtest
{:ok, result} = ExPostFacto.backtest(
  market_data,
  {SMAStrategy, :call, []},
  starting_balance: 100_000.0
)

# Display basic results
IO.puts("=== Backtest Results ===")
IO.puts("Starting Balance: $#{result.result.starting_balance}")
IO.puts("Final Balance: $#{result.result.final_balance}")
IO.puts("Total P&L: $#{result.result.total_profit_and_loss}")
IO.puts("Total Trades: #{length(result.result.trade_pairs)}")

# Get comprehensive statistics
stats = ExPostFacto.Result.comprehensive_summary(result.result)
IO.puts("Win Rate: #{Float.round(stats.win_rate_pct, 2)}%")
IO.puts("Sharpe Ratio: #{Float.round(stats.sharpe_ratio, 3)}")
```

## Advanced Visualization Examples

### Price Chart with Trade Signals

```elixir
# Cell 5: Create Interactive Price Chart
defmodule ChartHelpers do
  def prepare_price_data(market_data) do
    Enum.with_index(market_data, fn data, index ->
      %{
        "index" => index,
        "date" => data.timestamp,
        "open" => data.open,
        "high" => data.high,
        "low" => data.low,
        "close" => data.close,
        "volume" => data.volume
      }
    end)
  end

  def prepare_trade_data(trade_pairs, market_data) do
    # Map trade pairs to chart points
    indexed_data = Enum.with_index(market_data)

    Enum.flat_map(trade_pairs, fn pair ->
      entry_index = Enum.find_index(indexed_data, fn {data, _} ->
        data.timestamp == pair.entry_timestamp
      end)

      exit_index = if pair.exit_timestamp do
        Enum.find_index(indexed_data, fn {data, _} ->
          data.timestamp == pair.exit_timestamp
        end)
      else
        nil
      end

      signals = []

      # Add entry signal
      if entry_index do
        signals = [%{
          "index" => entry_index,
          "price" => pair.entry_price,
          "type" => "BUY",
          "color" => "green"
        } | signals]
      end

      # Add exit signal
      if exit_index do
        signals = [%{
          "index" => exit_index,
          "price" => pair.exit_price,
          "type" => "SELL",
          "color" => "red"
        } | signals]
      end

      signals
    end)
  end
end

# Prepare data for visualization
price_data = ChartHelpers.prepare_price_data(market_data)
trade_signals = ChartHelpers.prepare_trade_data(result.result.trade_pairs, market_data)

# Create the price chart
price_chart =
  Vl.new(width: 800, height: 400)
  |> Vl.data_from_values(price_data)
  |> Vl.mark(:line, color: "steelblue")
  |> Vl.encode_field(:x, "index", type: :quantitative, title: "Time")
  |> Vl.encode_field(:y, "close", type: :quantitative, title: "Price ($)")
  |> Vl.resolve(:scale, y: :independent)

# Add trade signals as overlay
signal_chart =
  Vl.new()
  |> Vl.data_from_values(trade_signals)
  |> Vl.mark(:circle, size: 100)
  |> Vl.encode_field(:x, "index", type: :quantitative)
  |> Vl.encode_field(:y, "price", type: :quantitative)
  |> Vl.encode_field(:color, "color", type: :nominal, scale: [range: ["green", "red"]])
  |> Vl.encode_field(:tooltip, ["type", "price"])

# Combine charts
final_chart = Vl.layer([price_chart, signal_chart])

Kino.VegaLite.new(final_chart)
```

### Performance Metrics Dashboard

```elixir
# Cell 6: Performance Dashboard
defmodule Dashboard do
  def create_equity_curve(result, market_data) do
    # Calculate running equity over time
    equity_data =
      result.result.data_points
      |> Enum.with_index()
      |> Enum.map(fn {point, index} ->
        %{
          "index" => index,
          "equity" => point.running_balance,
          "date" => Enum.at(market_data, index).timestamp
        }
      end)

    Vl.new(width: 600, height: 300, title: "Equity Curve")
    |> Vl.data_from_values(equity_data)
    |> Vl.mark(:line, color: "green", stroke_width: 2)
    |> Vl.encode_field(:x, "index", type: :quantitative, title: "Time")
    |> Vl.encode_field(:y, "equity", type: :quantitative, title: "Portfolio Value ($)")
  end

  def create_trade_distribution(trade_pairs) do
    trade_data =
      trade_pairs
      |> Enum.map(fn pair ->
        pnl_pct = ((pair.exit_price - pair.entry_price) / pair.entry_price) * 100
        %{
          "pnl_percent" => Float.round(pnl_pct, 2),
          "trade_type" => if pnl_pct > 0, do: "Winner", else: "Loser"
        }
      end)

    Vl.new(width: 400, height: 300, title: "Trade P&L Distribution")
    |> Vl.data_from_values(trade_data)
    |> Vl.mark(:bar)
    |> Vl.encode_field(:x, "pnl_percent", type: :quantitative, bin: true, title: "P&L (%)")
    |> Vl.encode(:y, aggregate: :count, title: "Count")
    |> Vl.encode_field(:color, "trade_type", type: :nominal,
                      scale: [domain: ["Winner", "Loser"], range: ["green", "red"]])
  end
end

# Create equity curve
equity_chart = Dashboard.create_equity_curve(result, market_data)
Kino.VegaLite.new(equity_chart)
```

```elixir
# Cell 7: Trade Distribution Chart
trade_dist_chart = Dashboard.create_trade_distribution(result.result.trade_pairs)
Kino.VegaLite.new(trade_dist_chart)
```

## Interactive Strategy Development

### Parameter Optimization

```elixir
# Cell 8: Interactive Parameter Testing
defmodule ParameterOptimizer do
  def test_sma_parameters(market_data, short_periods, long_periods) do
    results = for short <- short_periods, long <- long_periods, short < long do
      strategy = fn data, context ->
        SMAStrategy.call_with_params(data, context, short, long)
      end

      {:ok, result} = ExPostFacto.backtest(
        market_data,
        {__MODULE__, :wrap_strategy, [strategy]},
        starting_balance: 100_000.0
      )

      stats = ExPostFacto.Result.comprehensive_summary(result.result)

      %{
        short_period: short,
        long_period: long,
        total_return: stats.total_return_pct,
        sharpe_ratio: stats.sharpe_ratio,
        win_rate: stats.win_rate_pct,
        max_drawdown: stats.max_drawdown_pct
      }
    end

    # Find best performing combination
    best = Enum.max_by(results, & &1.sharpe_ratio)

    {results, best}
  end

  def wrap_strategy(data, context, strategy_fn) do
    strategy_fn.(data, context)
  end
end

# Test different parameter combinations
short_periods = [5, 10, 15]
long_periods = [20, 30, 50]

{param_results, best_params} = ParameterOptimizer.test_sma_parameters(
  market_data,
  short_periods,
  long_periods
)

IO.puts("=== Parameter Optimization Results ===")
IO.puts("Best Parameters: #{best_params.short_period}/#{best_params.long_period}")
IO.puts("Sharpe Ratio: #{Float.round(best_params.sharpe_ratio, 3)}")
IO.puts("Total Return: #{Float.round(best_params.total_return, 2)}%")
IO.puts("Win Rate: #{Float.round(best_params.win_rate, 2)}%")
```

### Real-time Strategy Testing

```elixir
# Cell 9: Interactive Strategy Form
form =
  Kino.Control.form([
    short_ma: Kino.Control.number("Short MA Period", default: 10),
    long_ma: Kino.Control.number("Long MA Period", default: 20),
    initial_balance: Kino.Control.number("Starting Balance", default: 100_000)
  ], submit: "Run Backtest")

Kino.Control.stream(form)
|> Kino.listen(fn %{data: %{short_ma: short, long_ma: long, initial_balance: balance}} ->
  if short < long do
    # Create modified strategy with custom parameters
    custom_strategy = fn data, context ->
      SMAStrategy.call_with_params(data, context, short, long)
    end

    {:ok, result} = ExPostFacto.backtest(
      market_data,
      {ParameterOptimizer, :wrap_strategy, [custom_strategy]},
      starting_balance: balance
    )

    stats = ExPostFacto.Result.comprehensive_summary(result.result)

    IO.puts("\n=== Custom Strategy Results ===")
    IO.puts("Parameters: #{short}/#{long} MA")
    IO.puts("Starting Balance: $#{balance}")
    IO.puts("Final Balance: $#{Float.round(result.result.final_balance, 2)}")
    IO.puts("Total Return: #{Float.round(stats.total_return_pct, 2)}%")
    IO.puts("Sharpe Ratio: #{Float.round(stats.sharpe_ratio, 3)}")
    IO.puts("Win Rate: #{Float.round(stats.win_rate_pct, 2)}%")
    IO.puts("Max Drawdown: #{Float.round(stats.max_drawdown_pct, 2)}%")
  else
    IO.puts("Error: Short MA period must be less than Long MA period")
  end
end)

form
```

## Loading Real Market Data

### CSV Data Import

```elixir
# Cell 10: Load Real Market Data
file_input = Kino.Input.file("Upload CSV file with OHLC data")
```

```elixir
# Cell 11: Process Uploaded Data
file_data = Kino.Input.read(file_input)

real_market_data = if file_data do
  content = file_data.file_ref |> Kino.Input.file_path() |> File.read!()

  # Parse CSV data (assuming standard OHLC format)
  lines = String.split(content, "\n", trim: true)
  [_header | data_lines] = lines

  Enum.map(data_lines, fn line ->
    [date, open, high, low, close, volume] = String.split(line, ",")

    %{
      timestamp: String.trim(date),
      open: String.to_float(String.trim(open)),
      high: String.to_float(String.trim(high)),
      low: String.to_float(String.trim(low)),
      close: String.to_float(String.trim(close)),
      volume: String.to_integer(String.trim(volume))
    }
  end)
else
  IO.puts("No file uploaded, using sample data")
  market_data
end

IO.puts("Loaded #{length(real_market_data)} data points")
IO.inspect(Enum.take(real_market_data, 3), label: "Sample real data")
```

## Best Practices

### 1. **Notebook Organization**

Structure your LiveBook notebooks with clear sections:

- **Setup**: Dependencies and imports
- **Data Loading**: Market data preparation
- **Strategy Definition**: Trading logic
- **Backtesting**: Running tests
- **Analysis**: Results and visualization
- **Optimization**: Parameter tuning

### 2. **Performance Considerations**

- Use `Enum.take/2` for large datasets in visualizations
- Cache expensive computations using `Kino.Process`
- Break complex analysis into smaller cells

### 3. **Data Management**

```elixir
# Use Kino.Process to cache large datasets
data_process = Kino.Process.start_link(fn ->
  # Load and process your large dataset here
  heavy_market_data = load_large_dataset()
  heavy_market_data
end)

# Access cached data
cached_data = Kino.Process.get(data_process)
```

### 4. **Error Handling**

```elixir
# Always validate data before backtesting
case ExPostFacto.validate_data(market_data) do
  :ok ->
    {:ok, result} = ExPostFacto.backtest(market_data, strategy)
    # Process results...

  {:error, reason} ->
    IO.puts("Data validation failed: #{reason}")
    # Handle error...
end
```

## Common Use Cases

### 1. **Strategy Research and Development**

- Interactive strategy prototyping
- Parameter sensitivity analysis
- Comparative backtesting

### 2. **Educational and Training**

- Teaching trading concepts
- Demonstrating strategy performance
- Risk management education

### 3. **Team Collaboration**

- Sharing analysis notebooks
- Collaborative strategy development
- Results presentation

### 4. **Portfolio Analysis**

- Multi-strategy comparison
- Risk-adjusted performance metrics
- Correlation analysis

## Troubleshooting

### Common Issues

**1. Dependency Loading Errors**

```elixir
# If you get dependency errors, restart the runtime and try:
Mix.install([
  {:ex_post_facto, "~> 0.2.0"},
  {:kino, "~> 0.12.0"},
  {:kino_vega_lite, "~> 0.1.0"}
], force: true)
```

**2. Memory Issues with Large Datasets**

```elixir
# Process data in chunks for large files
defmodule DataProcessor do
  def process_in_chunks(data, chunk_size \\ 1000) do
    data
    |> Enum.chunk_every(chunk_size)
    |> Enum.map(&process_chunk/1)
    |> List.flatten()
  end

  defp process_chunk(chunk) do
    # Process each chunk separately
    chunk
  end
end
```

**3. Visualization Performance**

```elixir
# Limit data points for charts
limited_data = Enum.take_every(large_dataset, 10)  # Take every 10th point
```

## Additional Resources

- [LiveBook Documentation](https://livebook.dev/docs/)
- [VegaLite for Elixir](https://github.com/livebook-dev/vega_lite)
- [Kino Documentation](https://hexdocs.pm/kino/)
- [ExPostFacto Strategy API Guide](STRATEGY_API.md)
- [ExPostFacto Data Handling Examples](ENHANCED_DATA_HANDLING_EXAMPLES.md)

## Sample Notebooks

Complete example notebooks are available in the `notebooks/` directory:

- `basic_backtesting.livemd` - Introduction to backtesting in LiveBook
- `strategy_optimization.livemd` - Parameter optimization workflows
- `advanced_visualization.livemd` - Complex charting and analysis
- `real_data_analysis.livemd` - Working with real market data

Happy backtesting! 🚀📈
