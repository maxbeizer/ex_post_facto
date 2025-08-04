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
    # Seed the random number generator for reproducible results
    :rand.seed(:exsss, {123, 456, 789})

    Enum.reduce(1..days, [], fn day, acc ->
      prev_close = if acc == [], do: base_price, else: hd(acc).close

      # Create multiple overlapping cycles to generate interesting crossovers
      # Short cycle for immediate reversals (good for fast MA)
      short_cycle = :math.sin(day * 2 * :math.pi() / 12) * 12

      # Medium cycle for trend changes (good for slow MA crossovers)
      medium_cycle = :math.sin(day * 2 * :math.pi() / 25) * 20

      # Long cycle for overall market direction
      long_cycle = :math.sin(day * 2 * :math.pi() / 60) * 30

      # Add volatility spikes at certain intervals
      volatility_spike = if rem(day, 20) in [0, 1, 2], do: (:rand.uniform() - 0.5) * 30, else: 0

      # Combine all components with higher weightings for more movement
      price_movement = short_cycle * 0.6 + medium_cycle * 0.7 + long_cycle * 0.4 + volatility_spike

      # Add controlled noise
      noise = (:rand.uniform() - 0.5) * 3

      # Calculate OHLC based on the movement
      direction = if price_movement > 0, do: 1, else: -1
      magnitude = abs(price_movement) + abs(noise)

      open = prev_close + noise
      close = open + price_movement + (noise * 0.5)

      # Create realistic high/low based on direction and magnitude
      {high, low} = if direction > 0 do
        high = max(open, close) + magnitude * 0.3 + :rand.uniform() * 2
        low = min(open, close) - :rand.uniform() * 1.5
        {high, low}
      else
        high = max(open, close) + :rand.uniform() * 1.5
        low = min(open, close) - magnitude * 0.3 - :rand.uniform() * 2
        {high, low}
      end

      point = %{
        open: Float.round(max(open, 1.0), 2),
        high: Float.round(max(high, 1.0), 2),
        low: Float.round(max(low, 1.0), 2),
        close: Float.round(max(close, 1.0), 2),
        volume: (:rand.uniform(800000) + 200000) * 1.0,
        timestamp: Date.add(~D[2023-01-01], day - 1) |> Date.to_string()
      }

      [point | acc]
    end) |> Enum.reverse()
  end
end

# Generate 100 days of sample market data with multiple crossover opportunities
market_data = SampleData.generate_ohlc(100)

IO.puts("Generated #{length(market_data)} data points")
IO.inspect(Enum.take(market_data, 3), label: "Sample data")

# Show the price range and some statistics to understand the data better
prices = Enum.map(market_data, & &1.close)
min_price = Enum.min(prices)
max_price = Enum.max(prices)
price_range = max_price - min_price
avg_price = Enum.sum(prices) / length(prices)

IO.puts("Price range: $#{Float.round(min_price, 2)} - $#{Float.round(max_price, 2)}")
IO.puts("Price range span: $#{Float.round(price_range, 2)} (#{Float.round(price_range / avg_price * 100, 1)}%)")
IO.puts("Average price: $#{Float.round(avg_price, 2)}")

# Quick check for volatility - count significant price changes
significant_moves = Enum.zip(prices, tl(prices))
|> Enum.count(fn {prev, curr} -> abs(curr - prev) / prev > 0.02 end)  # 2% moves

IO.puts("Days with >2% price moves: #{significant_moves} out of #{length(prices) - 1}")

# Show some sample price movements to verify we have good volatility
IO.puts("\n📈 Sample Price Movements (first 20 days):")
first_20_prices = Enum.take(prices, 20)
for {price, index} <- Enum.with_index(first_20_prices) do
  change = if index > 0 do
    prev_price = Enum.at(first_20_prices, index - 1)
    change_pct = (price - prev_price) / prev_price * 100
    " (#{if change_pct > 0, do: "+", else: ""}#{Float.round(change_pct, 1)}%)"
  else
    ""
  end
  IO.puts("Day #{index + 1}: $#{price}#{change}")
end

IO.puts("This should generate multiple moving average crossovers! 📈📉")
```

```elixir
# Cell 3: Moving Average Strategies
defmodule SMAStrategy do
  @doc "Simple test strategy - buy then sell"
  def test_call(%ExPostFacto.InputData{} = data, %ExPostFacto.Result{is_position_open: is_position_open} = result) do
    IO.inspect({data, result}, label: "Test strategy called with")

    # Simple strategy: buy on first call, sell on second call
    if !is_position_open do
      IO.puts("TEST BUY SIGNAL!")
      :buy
    else
      IO.puts("TEST SELL SIGNAL!")
      :close_buy
    end
  end

  @doc """
  Simple trend-following strategy based on price action.
  This is a simplified strategy that works with MFA pattern.
  For complex strategies with indicators, use the Strategy behavior instead.
  """
  def simple_trend_call(%ExPostFacto.InputData{close: price}, %ExPostFacto.Result{is_position_open: is_position_open}) do
    # Dynamic strategy: buy when price is above average + buffer, sell when below average - buffer
    # Use more responsive thresholds based on the enhanced data generation
    avg_price = 100.0  # Base price from our data generator
    buy_threshold = avg_price * 1.08   # 8% above average (more sensitive)
    sell_threshold = avg_price * 0.92  # 8% below average (more sensitive)

    cond do
      !is_position_open && price > buy_threshold ->
        :buy
      is_position_open && price < sell_threshold ->
        :close_buy
      true ->
        :noop
    end
  end

  @doc """
  Adaptive trend strategy that calculates thresholds based on recent price action.
  More sophisticated version that should generate more trades.
  """
  def adaptive_trend_call(%ExPostFacto.InputData{close: price}, %ExPostFacto.Result{data_points: data_points, is_position_open: is_position_open}) do
    # Calculate dynamic thresholds based on recent price action
    recent_prices = data_points
    |> Enum.take(20)  # Look at last 20 data points
    |> Enum.map(fn dp -> dp.datum.close end)

    if length(recent_prices) >= 5 do
      avg_recent = Enum.sum(recent_prices) / length(recent_prices)
      price_std = calculate_std_dev(recent_prices, avg_recent)

      # Use standard deviation to set dynamic thresholds - more aggressive
      buy_threshold = avg_recent + (price_std * 0.3)  # Reduced from 0.5 to 0.3
      sell_threshold = avg_recent - (price_std * 0.3)  # More sensitive thresholds

      cond do
        !is_position_open && price > buy_threshold ->
          :buy
        is_position_open && price < sell_threshold ->
          :close_buy
        true ->
          :noop
      end
    else
      # Not enough data, use simple price level strategy - more responsive
      cond do
        !is_position_open && price > 105.0 ->  # Reduced threshold
          :buy
        is_position_open && price < 95.0 ->   # Reduced threshold
          :close_buy
        true ->
          :noop
      end
    end
  end

  defp calculate_std_dev(prices, avg) do
    variance = prices
    |> Enum.map(fn price -> :math.pow(price - avg, 2) end)
    |> Enum.sum()
    |> Kernel./(length(prices))

    :math.sqrt(variance)
  end
end

# For proper moving average strategies, we should use the Strategy behavior:
defmodule ProperSMAStrategy do
  @moduledoc """
  Proper implementation using ExPostFacto.Strategy behavior.
  This is the recommended approach for stateful strategies.
  """

  use ExPostFacto.Strategy

  def init(opts) do
    fast_period = Keyword.get(opts, :fast_period, 5)
    slow_period = Keyword.get(opts, :slow_period, 10)

    if fast_period >= slow_period do
      {:error, "fast_period must be less than slow_period"}
    else
      {:ok, %{
        fast_period: fast_period,
        slow_period: slow_period,
        price_history: [],
        fast_sma_history: [],
        slow_sma_history: []
      }}
    end
  end

  def next(state) do
    current_price = data().close
    updated_price_history = [current_price | state.price_history]

    # Calculate SMAs if we have enough data
    {fast_sma, slow_sma} = calculate_smas(updated_price_history, state.fast_period, state.slow_period)

    # Make trading decisions based on SMA crossover
    make_trading_decision(fast_sma, slow_sma, state)

    new_state = %{
      state |
      price_history: updated_price_history,
      fast_sma_history: [fast_sma | state.fast_sma_history],
      slow_sma_history: [slow_sma | state.slow_sma_history]
    }

    {:ok, new_state}
  end

  defp calculate_smas(price_history, fast_period, slow_period) do
    fast_sma = if length(price_history) >= fast_period do
      indicator(:sma, price_history, fast_period) |> List.first()
    else
      0.0
    end

    slow_sma = if length(price_history) >= slow_period do
      indicator(:sma, price_history, slow_period) |> List.first()
    else
      0.0
    end

    {fast_sma, slow_sma}
  end

  defp make_trading_decision(fast_sma, slow_sma, state) do
    current_position = position()

    # Check for crossovers using the built-in crossover detection
    fast_sma_history = [fast_sma | state.fast_sma_history]
    slow_sma_history = [slow_sma | state.slow_sma_history]

    cond do
      # Fast SMA crosses above slow SMA - buy signal
      length(fast_sma_history) >= 2 and length(slow_sma_history) >= 2 and
      crossover?(fast_sma_history, slow_sma_history) and current_position != :long ->
        if current_position == :short, do: close_sell()
        buy()

      # Fast SMA crosses below slow SMA - sell signal
      length(fast_sma_history) >= 2 and length(slow_sma_history) >= 2 and
      crossover?(slow_sma_history, fast_sma_history) and current_position != :short ->
        if current_position == :long, do: close_buy()
        sell()

      true ->
        :ok
    end
  end
end
```

```elixir
# Cell 4: Test Simple Strategy First
IO.puts("Testing simple strategy first...")
{:ok, test_result} = ExPostFacto.backtest(
  Enum.take(market_data, 5),  # Just test with 5 data points first
  {SMAStrategy, :test_call, []},
  starting_balance: 100_000.0
)

IO.puts("Test result: #{test_result.result.total_profit_and_loss}")
```

```elixir
# Cell 5: Test Different Strategies

IO.puts("=== Testing Simple Trend Strategy (MFA) ===")
{:ok, result1} = ExPostFacto.backtest(
  market_data,
  {SMAStrategy, :simple_trend_call, []},
  starting_balance: 100_000.0
)

IO.puts("=== Testing Adaptive Trend Strategy (MFA) ===")
{:ok, result1_adaptive} = ExPostFacto.backtest(
  market_data,
  {SMAStrategy, :adaptive_trend_call, []},
  starting_balance: 100_000.0
)

IO.puts("=== Testing Built-in SMA Strategy (Fast: 3, Slow: 8) ===")
{:ok, result2} = ExPostFacto.backtest(
  market_data,
  {ExPostFacto.ExampleStrategies.SmaStrategy, [fast_period: 3, slow_period: 8]},
  starting_balance: 100_000.0
)

IO.puts("=== Testing Built-in SMA Strategy (Fast: 5, Slow: 15) ===")
{:ok, result3} = ExPostFacto.backtest(
  market_data,
  {ExPostFacto.ExampleStrategies.SmaStrategy, [fast_period: 5, slow_period: 15]},
  starting_balance: 100_000.0
)

# Display all results
strategies = [
  {"Simple Trend", result1},
  {"Adaptive Trend", result1_adaptive},
  {"SMA (3/8)", result2},
  {"SMA (5/15)", result3}
]

IO.puts("\n" <> String.duplicate("=", 80))
IO.puts("📊 STRATEGY COMPARISON RESULTS")
IO.puts(String.duplicate("=", 80))

{best_strategy, best_balance} =
  Enum.reduce(strategies, {nil, 0.0}, fn {name, result}, {current_best_strategy, current_best_balance} ->
    stats = ExPostFacto.Result.comprehensive_summary(result.result)
    trade_count = length(result.result.trade_pairs)

    IO.puts("\n🎯 #{name} Strategy:")
    IO.puts("   Starting Balance: $#{Float.round(result.result.starting_balance * 1.0, 2)}")
    IO.puts("   Final Balance:    $#{Float.round(stats.final_balance * 1.0, 2)}")
    IO.puts("   Total P&L:        $#{Float.round(result.result.total_profit_and_loss * 1.0, 2)}")
    IO.puts("   Total Trades:     #{trade_count}")
    IO.puts("   Position Open:    #{result.result.is_position_open}")
    IO.puts("   Win Rate:         #{Float.round(stats.win_rate * 1.0, 1)}%")

    if trade_count > 0 do
      IO.puts("   Sharpe Ratio:     #{Float.round(stats.sharpe_ratio * 1.0, 3)}")
      IO.puts("   Max Drawdown:     #{Float.round(stats.max_drawdown_pct * 1.0, 1)}%")
    end

    # Update best strategy based on final balance
    if stats.final_balance > current_best_balance do
      {name, stats.final_balance}
    else
      {current_best_strategy, current_best_balance}
    end
  end)

IO.puts("\n🏆 Best performing strategy: #{best_strategy || "None"}")
IO.puts("💰 Best final balance: $#{Float.round(best_balance * 1.0, 2)}")

# Show trade activity summary
IO.puts("\n📈 Trade Activity Summary:")
total_trades = Enum.sum(Enum.map(strategies, fn {_, result} -> length(result.result.trade_pairs) end))
IO.puts("   Total trades across all strategies: #{total_trades}")

if total_trades > 0 do
  IO.puts("   ✅ Success! Multiple strategies generated trades")
  IO.puts("   📊 This data is much more interesting for analysis")
else
  IO.puts("   ⚠️  No trades generated - need more volatile data")
end
```

## Advanced Visualization Examples

### Understanding ExPostFacto Strategy Architecture

Before diving into visualizations, it's important to understand why our initial moving average strategy may not generate trades:

**The Issue**: ExPostFacto's `result.data_points` contains **processed trading actions**, not raw historical price data. When a strategy function is called, `data_points` only contains previously executed trades, which is why it was always empty in our debug output.

**The Solution**: Strategies must maintain their own price history for indicator calculations. ExPostFacto provides two approaches:

1. **Simple MFA Pattern**: For basic strategies without complex state
2. **Strategy Behavior**: For advanced strategies that need to maintain historical data

The proper moving average strategy shown above uses the Strategy behavior, which is the recommended approach for any strategy that needs to calculate technical indicators.

**Note**: For production use, ExPostFacto includes several pre-built strategies like `ExPostFacto.ExampleStrategies.SmaStrategy` that are well-tested and optimized. The custom `ProperSMAStrategy` shown above is for educational purposes to demonstrate the Strategy behavior pattern.

### Key Takeaways:

- `result.data_points` = completed trading actions
- `result.is_position_open` = current position state
- Price history must be maintained by the strategy itself
- Use Strategy behavior for stateful strategies
- Use MFA pattern for simple, stateless logic

### Price Chart with Trade Signals

```elixir
# Cell 6: Create Interactive Price Chart
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
      # Extract timestamps from the DataPoint structs
      entry_timestamp = pair.enter_point.datum.timestamp
      exit_timestamp = if pair.exit_point, do: pair.exit_point.datum.timestamp, else: nil

      entry_index = Enum.find_index(indexed_data, fn {data, _} ->
        # Convert both timestamps to strings for comparison
        data_timestamp = case data.timestamp do
          %DateTime{} = dt -> DateTime.to_string(dt)
          date_string when is_binary(date_string) -> date_string
          other -> to_string(other)
        end

        entry_timestamp_str = case entry_timestamp do
          %DateTime{} = dt -> DateTime.to_string(dt)
          date_string when is_binary(date_string) -> date_string
          other -> to_string(other)
        end

        data_timestamp == entry_timestamp_str
      end)

      exit_index = if exit_timestamp do
        Enum.find_index(indexed_data, fn {data, _} ->
          # Convert both timestamps to strings for comparison
          data_timestamp = case data.timestamp do
            %DateTime{} = dt -> DateTime.to_string(dt)
            date_string when is_binary(date_string) -> date_string
            other -> to_string(other)
          end

          exit_timestamp_str = case exit_timestamp do
            %DateTime{} = dt -> DateTime.to_string(dt)
            date_string when is_binary(date_string) -> date_string
            other -> to_string(other)
          end

          data_timestamp == exit_timestamp_str
        end)
      else
        nil
      end

      signals = []

      # Add entry signal
      signals = if entry_index do
        entry_price = pair.enter_point.datum.close
        [%{
          "index" => entry_index,
          "price" => entry_price,
          "type" => "BUY",
          "color" => "green"
        } | signals]
      else
        signals
      end

      # Add exit signal
      signals = if exit_index do
        exit_price = pair.exit_point.datum.close
        [%{
          "index" => exit_index,
          "price" => exit_price,
          "type" => "SELL",
          "color" => "red"
        } | signals]
      else
        signals
      end

      signals
    end)
  end
end

# Prepare data for visualization - use the SMA strategy result that should have trades
price_data = ChartHelpers.prepare_price_data(market_data)
trade_signals = ChartHelpers.prepare_trade_data(result2.result.trade_pairs, market_data)

IO.puts("Preparing chart with #{length(trade_signals)} trade signals from SMA strategy")

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
  |> Vl.encode(:tooltip, [
    [field: "type", type: :nominal],
    [field: "price", type: :quantitative]
  ])

# Combine charts using the concat approach for VegaLite 0.1.11
final_chart =
  Vl.new(width: 800, height: 400)
  |> Vl.data_from_values(price_data)
  |> Vl.layers([
    Vl.new()
    |> Vl.mark(:line, color: "steelblue")
    |> Vl.encode_field(:x, "index", type: :quantitative, title: "Time")
    |> Vl.encode_field(:y, "close", type: :quantitative, title: "Price ($)"),

    Vl.new()
    |> Vl.data_from_values(trade_signals)
    |> Vl.mark(:circle, size: 100)
    |> Vl.encode_field(:x, "index", type: :quantitative)
    |> Vl.encode_field(:y, "price", type: :quantitative)
    |> Vl.encode_field(:color, "color", type: :nominal, scale: [range: ["green", "red"]])
    |> Vl.encode(:tooltip, [
      [field: "type", type: :nominal],
      [field: "price", type: :quantitative]
    ])
  ])

Kino.VegaLite.new(final_chart)
```

### Performance Metrics Dashboard

```elixir
# Cell 7: Performance Dashboard
defmodule Dashboard do
  def create_equity_curve(result, market_data) do
    # Calculate running equity over time from trade pairs and starting balance
    starting_balance = result.result.starting_balance

    # If no trades were made, create a flat line at starting balance
    if length(result.result.trade_pairs) == 0 do
      equity_data =
        market_data
        |> Enum.with_index()
        |> Enum.map(fn {data, index} ->
          %{
            "index" => index,
            "equity" => starting_balance,
            "date" => data.timestamp
          }
        end)

      Vl.new(width: 600, height: 300, title: "Equity Curve")
      |> Vl.data_from_values(equity_data)
      |> Vl.mark(:line, color: "green", stroke_width: 2)
      |> Vl.encode_field(:x, "index", type: :quantitative, title: "Time")
      |> Vl.encode_field(:y, "equity", type: :quantitative, title: "Portfolio Value ($)")
    else
      # Calculate equity at each trade point
      equity_points =
        result.result.trade_pairs
        |> Enum.reverse()  # Start from earliest trade
        |> Enum.reduce([{0, starting_balance}], fn trade_pair, acc ->
          # Find the index of this trade in the market data
          enter_timestamp = trade_pair.enter_point.datum.timestamp
          exit_timestamp = if trade_pair.exit_point, do: trade_pair.exit_point.datum.timestamp, else: nil

          enter_index = Enum.find_index(market_data, fn data ->
            case data.timestamp do
              %DateTime{} = dt -> DateTime.to_string(dt) == to_string(enter_timestamp)
              timestamp_str -> timestamp_str == to_string(enter_timestamp)
            end
          end) || 0

          exit_index = if exit_timestamp do
            Enum.find_index(market_data, fn data ->
              case data.timestamp do
                %DateTime{} = dt -> DateTime.to_string(dt) == to_string(exit_timestamp)
                timestamp_str -> timestamp_str == to_string(exit_timestamp)
              end
            end)
          else
            nil
          end

          # Add entry point
          new_acc = [{enter_index, trade_pair.previous_balance} | acc]

          # Add exit point if trade is complete
          if exit_index do
            [{exit_index, trade_pair.balance} | new_acc]
          else
            new_acc
          end
        end)
        |> Enum.reverse()
        |> Enum.sort_by(fn {index, _balance} -> index end)

      # Interpolate equity for all data points
      equity_data =
        market_data
        |> Enum.with_index()
        |> Enum.map(fn {data, index} ->
          # Find the most recent equity point at or before this index
          equity = case Enum.reverse(Enum.filter(equity_points, fn {eq_index, _} -> eq_index <= index end)) do
            [{_, balance} | _] -> balance
            [] -> starting_balance
          end

          %{
            "index" => index,
            "equity" => equity,
            "date" => data.timestamp
          }
        end)

      Vl.new(width: 600, height: 300, title: "Equity Curve")
      |> Vl.data_from_values(equity_data)
      |> Vl.mark(:line, color: "green", stroke_width: 2)
      |> Vl.encode_field(:x, "index", type: :quantitative, title: "Time")
      |> Vl.encode_field(:y, "equity", type: :quantitative, title: "Portfolio Value ($)")
    end
  end

  def create_trade_distribution(trade_pairs) do
    trade_data =
      trade_pairs
      |> Enum.map(fn pair ->
        # Extract prices from the DataPoint structs
        entry_price = pair.enter_point.datum.close
        exit_price = if pair.exit_point, do: pair.exit_point.datum.close, else: entry_price

        pnl_pct = ((exit_price - entry_price) / entry_price) * 100
        %{
          "pnl_percent" => Float.round(pnl_pct, 2),
          "trade_type" => if(pnl_pct > 0, do: "Winner", else: "Loser")
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

# Create equity curve using the strategy with the most trades
strategies_with_trades = Enum.filter([
  {"Simple Trend", result1},
  {"Adaptive Trend", result1_adaptive},
  {"SMA (3/8)", result2},
  {"SMA (5/15)", result3}
], fn {_, result} -> length(result.result.trade_pairs) > 0 end)

best_strategy_result = if length(strategies_with_trades) > 0 do
  {_, result} = Enum.max_by(strategies_with_trades, fn {_, result} -> length(result.result.trade_pairs) end)
  result
else
  result2  # Fallback to SMA strategy
end

equity_chart = Dashboard.create_equity_curve(best_strategy_result, market_data)
Kino.VegaLite.new(equity_chart)
```

```elixir
# Cell 8: Trade Distribution Chart
trade_dist_chart = Dashboard.create_trade_distribution(best_strategy_result.result.trade_pairs)
Kino.VegaLite.new(trade_dist_chart)
```

## Interactive Strategy Development

### Parameter Optimization

```elixir
# Cell 9: Interactive Parameter Testing
defmodule ParameterOptimizer do
  def test_sma_parameters(market_data, short_periods, long_periods) do
    results = for short <- short_periods, long <- long_periods, short < long do
      # Use the built-in SMA strategy from ExPostFacto
      {:ok, result} = ExPostFacto.backtest(
        market_data,
        {ExPostFacto.ExampleStrategies.SmaStrategy, [fast_period: short, slow_period: long]},
        starting_balance: 100_000.0
      )

      stats = ExPostFacto.Result.comprehensive_summary(result.result)

      %{
        short_period: short,
        long_period: long,
        total_return: stats.total_return_pct,
        sharpe_ratio: stats.sharpe_ratio,
        win_rate: stats.win_rate,
        max_drawdown: stats.max_drawdown_pct
      }
    end

    # Find best performing combination by Sharpe ratio, but handle empty results
    best = if length(results) > 0 do
      Enum.max_by(results, & &1.sharpe_ratio)
    else
      %{short_period: 0, long_period: 0, total_return: 0.0, sharpe_ratio: 0.0, win_rate: 0.0, max_drawdown: 0.0}
    end

    {results, best}
  end
end

# Test different parameter combinations - using shorter periods for more responsive strategies
short_periods = [3, 5, 8]
long_periods = [10, 15, 20]

{param_results, best_params} = ParameterOptimizer.test_sma_parameters(
  market_data,
  short_periods,
  long_periods
)

IO.puts("=== Parameter Optimization Results ===")
IO.puts("Tested #{length(param_results)} parameter combinations")

# Show all results, not just the best
IO.puts("\n📊 All Parameter Combinations:")
for result <- param_results do
  IO.puts("#{result.short_period}/#{result.long_period}: Return #{Float.round(result.total_return * 1.0, 1)}%, Sharpe #{Float.round(result.sharpe_ratio * 1.0, 2)}, Win Rate #{Float.round(result.win_rate * 1.0, 1)}%")
end

IO.puts("\n🏆 Best Parameters: #{best_params.short_period}/#{best_params.long_period}")
IO.puts("📈 Sharpe Ratio: #{Float.round(best_params.sharpe_ratio * 1.0, 3)}")
IO.puts("💰 Total Return: #{Float.round(best_params.total_return * 1.0, 2)}%")
IO.puts("🎯 Win Rate: #{Float.round(best_params.win_rate * 1.0, 2)}%")
IO.puts("📉 Max Drawdown: #{Float.round(best_params.max_drawdown * 1.0, 2)}%")
```

### Real-time Strategy Testing

```elixir
# Cell 10: Interactive Strategy Form
form =
  Kino.Control.form([
    short_ma: Kino.Control.number("Short MA Period", default: 10),
    long_ma: Kino.Control.number("Long MA Period", default: 20),
    initial_balance: Kino.Control.number("Starting Balance", default: 100_000)
  ], submit: "Run Backtest")

Kino.Control.stream(form)
|> Kino.listen(fn %{data: %{short_ma: short, long_ma: long, initial_balance: balance}} ->
  if short < long do
    # Use the built-in SMA strategy from ExPostFacto
    {:ok, result} = ExPostFacto.backtest(
      market_data,
      {ExPostFacto.ExampleStrategies.SmaStrategy, [fast_period: short, slow_period: long]},
      starting_balance: balance
    )

    stats = ExPostFacto.Result.comprehensive_summary(result.result)

    stats = ExPostFacto.Result.comprehensive_summary(result.result)

    IO.puts("\n=== Custom Strategy Results ===")
    IO.puts("Parameters: #{short}/#{long} MA")
    IO.puts("Starting Balance: $#{balance}")
    IO.puts("Final Balance: $#{Float.round(stats.final_balance * 1.0, 2)}")
    IO.puts("Total Return: #{Float.round(stats.total_return_pct * 1.0, 2)}%")
    IO.puts("Sharpe Ratio: #{Float.round(stats.sharpe_ratio * 1.0, 3)}")
    IO.puts("Win Rate: #{Float.round(stats.win_rate * 1.0, 2)}%")
    IO.puts("Max Drawdown: #{Float.round(stats.max_drawdown_pct * 1.0, 2)}%")
  else
    IO.puts("Error: Short MA period must be less than Long MA period")
  end
end)

form
```

## Loading Real Market Data

### CSV Data Import

```elixir
# Cell 11: Load Real Market Data
file_input = Kino.Input.file("Upload CSV file with OHLC data")
```

```elixir
# Cell 12: Process Uploaded Data
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
