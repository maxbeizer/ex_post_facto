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
# Cell 2: Sample Data Generation with EXTREME Volatility
defmodule SampleData do
  def generate_ohlc(days \\ 100, base_price \\ 100.0) do
    # Seed the random number generator for reproducible results
    :rand.seed(:exsss, {123, 456, 789})

    Enum.reduce(1..days, [], fn day, acc ->
      prev_close = if acc == [], do: base_price, else: hd(acc).close

      # Create MUCH more aggressive cycles for guaranteed crossovers
      # Ultra-short cycle for rapid reversals every few days
      short_cycle = :math.sin(day * 2 * :math.pi() / 3) * 6  # Every 3 days, ±6 points

      # Medium cycle for trend changes
      medium_cycle = :math.sin(day * 2 * :math.pi() / 7) * 8  # Every 7 days, ±8 points

      # Long cycle for overall market direction
      long_cycle = :math.sin(day * 2 * :math.pi() / 15) * 12  # Every 15 days, ±12 points

      # Add FREQUENT volatility spikes
      volatility_spike = if rem(day, 4) in [0, 1], do: (:rand.uniform() - 0.5) * 10, else: 0

      # Add random "market events" every few days
      market_event = if rem(day, 8) == 0, do: (:rand.uniform() - 0.5) * 15, else: 0

      # Add daily noise to ensure constant movement
      daily_noise = (:rand.uniform() - 0.5) * 4

      # Combine ALL components for maximum movement
      price_movement = short_cycle * 1.5 + medium_cycle * 1.3 + long_cycle * 1.0 + volatility_spike + market_event + daily_noise

      # Calculate OHLC based on the movement
      direction = if price_movement > 0, do: 1, else: -1
      magnitude = abs(price_movement)

      open = prev_close
      close = open + price_movement

      # Create realistic high/low with extra spread
      {high, low} = if direction > 0 do
        high = max(open, close) + magnitude * 0.2 + :rand.uniform() * 1
        low = min(open, close) - :rand.uniform() * 0.5
        {high, low}
      else
        high = max(open, close) + :rand.uniform() * 0.5
        low = min(open, close) - magnitude * 0.2 - :rand.uniform() * 1
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

# Generate 100 days of sample market data with EXTREME volatility for guaranteed trades
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

# Count extreme price moves for strategy triggers
significant_moves = Enum.zip(prices, tl(prices))
|> Enum.count(fn {prev, curr} -> abs(curr - prev) / prev > 0.02 end)  # 2% moves

large_moves = Enum.zip(prices, tl(prices))
|> Enum.count(fn {prev, curr} -> abs(curr - prev) / prev > 0.05 end)  # 5% moves

IO.puts("Days with >2% price moves: #{significant_moves} out of #{length(prices) - 1}")
IO.puts("Days with >5% price moves: #{large_moves} out of #{length(prices) - 1}")

# Show some sample price movements to verify we have EXTREME volatility
IO.puts("\n📈 Sample Price Movements (first 25 days):")
first_25_prices = Enum.take(prices, 25)
for {price, index} <- Enum.with_index(first_25_prices) do
  change = if index > 0 do
    prev_price = Enum.at(first_25_prices, index - 1)
    change_pct = (price - prev_price) / prev_price * 100
    " (#{if change_pct > 0, do: "+", else: ""}#{Float.round(change_pct, 1)}%)"
  else
    ""
  end
  IO.puts("Day #{index + 1}: $#{price}#{change}")
end

# Show key threshold levels for our ULTRA-SENSITIVE strategies
IO.puts("\n🎯 Strategy Threshold Analysis:")
IO.puts("   Simple Trend Buy Threshold:  $101.00 (1% above $100)")
IO.puts("   Simple Trend Sell Threshold: $99.00 (1% below $100)")
IO.puts("   Price crosses above $101: #{Enum.count(prices, &(&1 > 101.0))} times")
IO.puts("   Price crosses below $99: #{Enum.count(prices, &(&1 < 99.0))} times")
IO.puts("   Oscillator triggers (±$0.25 moves): #{Enum.zip(prices, tl(prices)) |> Enum.count(fn {prev, curr} -> abs(curr - prev) > 0.25 end)} times")

# Additional analysis for debugging strategy triggers
oscillator_triggers = Enum.zip(prices, tl(prices)) |> Enum.count(fn {prev, curr} -> abs(curr - prev) > 0.25 end)
big_oscillator_triggers = Enum.zip(prices, tl(prices)) |> Enum.count(fn {prev, curr} -> abs(curr - prev) > 1.0 end)

IO.puts("\n🔍 STRATEGY TRIGGER ANALYSIS:")
IO.puts("   Expected Oscillator trades (±$0.25): #{oscillator_triggers}")
IO.puts("   Expected big moves (±$1.00): #{big_oscillator_triggers}")
IO.puts("   Price variance: #{Float.round(Enum.reduce(prices, 0, fn p, acc -> acc + :math.pow(p - avg_price, 2) end) / length(prices), 2)}")

# Show first 10 day-to-day changes
IO.puts("\n📈 Day-to-Day Price Changes (first 10 days):")
Enum.zip(Enum.take(prices, 10), tl(Enum.take(prices, 11)))
|> Enum.with_index()
|> Enum.each(fn {{prev, curr}, i} ->
  change = curr - prev
  IO.puts("   Day #{i + 1} → #{i + 2}: $#{Float.round(prev, 2)} → $#{Float.round(curr, 2)} (#{if change > 0, do: "+", else: ""}#{Float.round(change, 2)})")
end)

# Calculate some simple moving averages to see if we'll get crossovers
if length(prices) >= 3 do
  last_3_prices = Enum.take(prices, 3)
  ma_2 = Enum.sum(Enum.take(last_3_prices, 2)) / 2
  ma_3 = Enum.sum(last_3_prices) / 3

  IO.puts("\n📊 Moving Average Preview (latest data):")
  IO.puts("   2-day MA:  $#{Float.round(ma_2, 2)}")
  IO.puts("   3-day MA:  $#{Float.round(ma_3, 2)}")
  IO.puts("   Current Price: $#{Float.round(hd(prices), 2)}")
  IO.puts("   MA Difference: $#{Float.round(ma_2 - ma_3, 2)}")
end

IO.puts("\nThis should generate multiple moving average crossovers! 📈📉")
```

```elixir
# Cell 3: Moving Average Strategies
defmodule SMAStrategy do
  @doc "Simple test strategy - buy then sell"
  def test_call(%ExPostFacto.InputData{} = _data, %ExPostFacto.Result{is_position_open: is_position_open} = _result) do
    # Simple strategy: buy on first call, sell on second call
    if !is_position_open do
      :buy
    else
      :close_buy
    end
  end

  @doc """
  Simple trend-following strategy based on price action.
  This is a simplified strategy that works with MFA pattern.
  """
  def simple_trend_call(%ExPostFacto.InputData{close: price}, %ExPostFacto.Result{is_position_open: is_position_open}) do
    # ULTRA-AGGRESSIVE strategy: buy when price is above 101, sell when below 99
    buy_threshold = 101.0   # Just 1% above base price
    sell_threshold = 99.0   # Just 1% below base price

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
  Simple Moving Average crossover strategy using MFA pattern.
  ULTRA-AGGRESSIVE version that trades on any MA difference.
  """
  def sma_crossover_call(%ExPostFacto.InputData{close: price}, %ExPostFacto.Result{data_points: data_points, is_position_open: is_position_open}) do
    # Get recent closing prices from data points
    recent_prices = [price | Enum.map(data_points, fn dp -> dp.datum.close end)]

    # Use VERY short periods: 2-day and 3-day moving averages for maximum sensitivity
    fast_ma = calculate_sma(recent_prices, 2)
    slow_ma = calculate_sma(recent_prices, 3)

    # Only need 3 data points to start trading
    if length(recent_prices) >= 3 do
      # Get previous moving averages to detect crossovers
      prev_prices = tl(recent_prices)
      prev_fast_ma = calculate_sma(prev_prices, 2)
      prev_slow_ma = calculate_sma(prev_prices, 3)

      cond do
        # Fast MA crosses above slow MA (golden cross) - buy signal
        !is_position_open && fast_ma > slow_ma && prev_fast_ma <= prev_slow_ma ->
          :buy

        # Fast MA crosses below slow MA (death cross) - sell signal
        is_position_open && fast_ma < slow_ma && prev_fast_ma >= prev_slow_ma ->
          :close_buy

        # ALSO: Trade on significant MA divergence (ultra-aggressive)
        !is_position_open && fast_ma > slow_ma + 0.5 ->
          :buy

        is_position_open && fast_ma < slow_ma - 0.5 ->
          :close_buy

        true ->
          :noop
      end
    else
      # Start trading immediately with simple logic
      cond do
        !is_position_open && price > 100.0 ->
          :buy
        is_position_open && price < 100.0 ->
          :close_buy
        true ->
          :noop
      end
    end
  end

  @doc """
  Adaptive trend strategy that calculates thresholds based on recent price action.
  """
  def adaptive_trend_call(%ExPostFacto.InputData{close: price}, %ExPostFacto.Result{data_points: data_points, is_position_open: is_position_open}) do
    # ULTRA-AGGRESSIVE adaptive strategy with very tight thresholds
    recent_prices = [price | Enum.map(data_points, fn dp -> dp.datum.close end)]
    |> Enum.take(5)  # Look at just last 5 data points for maximum sensitivity

    if length(recent_prices) >= 2 do
      avg_recent = Enum.sum(recent_prices) / length(recent_prices)

      # Use TINY thresholds for maximum trading
      buy_threshold = avg_recent + 0.5  # Just 50 cents above recent average
      sell_threshold = avg_recent - 0.5  # Just 50 cents below recent average

      cond do
        !is_position_open && price > buy_threshold ->
          :buy
        is_position_open && price < sell_threshold ->
          :close_buy
        true ->
          :noop
      end
    else
      # Not enough data, use ultra-simple thresholds
      cond do
        !is_position_open && price > 100.5 ->  # Just 0.5% above base
          :buy
        is_position_open && price < 99.5 ->   # Just 0.5% below base
          :close_buy
        true ->
          :noop
      end
    end
  end

  @doc """
  Ultra-aggressive oscillator strategy that trades on every small price movement.
  This should generate MANY trades by buying low and selling high repeatedly.
  """
  def oscillator_call(%ExPostFacto.InputData{close: price}, %ExPostFacto.Result{data_points: data_points, is_position_open: is_position_open}) do
    # Get recent price to compare
    recent_prices = [price | Enum.map(data_points, fn dp -> dp.datum.close end)]
    |> Enum.take(3)

    if length(recent_prices) >= 2 do
      current_price = hd(recent_prices)
      prev_price = Enum.at(recent_prices, 1)

      # Trade on ANY price movement greater than $0.25
      price_change = current_price - prev_price

      cond do
        # Buy if price just dropped (buy the dip)
        !is_position_open && price_change < -0.25 ->
          :buy
        # Sell if price went up while we're long (take profit)
        is_position_open && price_change > 0.25 ->
          :close_buy
        # Also sell if we're down more than $1
        is_position_open && current_price < 99.0 ->
          :close_buy
        true ->
          :noop
      end
    else
      # First few data points - start trading immediately
      cond do
        !is_position_open && price < 100.0 ->
          :buy
        is_position_open && price > 100.0 ->
          :close_buy
        true ->
          :noop
      end
    end
  end

  # Helper function to calculate Simple Moving Average
  defp calculate_sma(prices, period) do
    if length(prices) >= period do
      prices
      |> Enum.take(period)
      |> Enum.sum()
      |> Kernel./(period)
    else
      0.0
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

IO.puts("=== Testing SMA Crossover Strategy (2/3 day MAs) ===")
{:ok, result_sma} = ExPostFacto.backtest(
  market_data,
  {SMAStrategy, :sma_crossover_call, []},
  starting_balance: 100_000.0
)

IO.puts("=== Testing Ultra-Aggressive Oscillator Strategy ===")
{:ok, result_oscillator} = ExPostFacto.backtest(
  market_data,
  {SMAStrategy, :oscillator_call, []},
  starting_balance: 100_000.0
)

# Using working built-in strategies for comparison
IO.puts("=== Testing Buy and Hold Strategy ===")
{:ok, result_buy_hold} = ExPostFacto.backtest(
  market_data,
  {ExPostFacto.ExampleStrategies.SimpleBuyHold, []},  # Strategy behavior format
  starting_balance: 100_000.0
)

# Display all results
strategies = [
  {"Simple Trend", result1},
  {"Adaptive Trend", result1_adaptive},
  {"SMA Crossover (2/3)", result_sma},
  {"Ultra Oscillator", result_oscillator},
  {"Buy & Hold", result_buy_hold}
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

ExPostFacto supports two different strategy patterns:

**1. MFA Pattern (Module-Function-Arguments)** - For simple, stateless strategies:

```elixir
# Custom functions we defined in SMAStrategy module
{SMAStrategy, :simple_trend_call, []}
{SMAStrategy, :sma_crossover_call, []}

# Built-in MFA strategies
{ExPostFacto.ExampleStrategies.BuyBuyBuy, :call, []}
{ExPostFacto.ExampleStrategies.Noop, :noop, []}
```

**2. Strategy Behavior** - For complex strategies with state management:

```elixir
# Built-in Strategy behavior implementations
{ExPostFacto.ExampleStrategies.SimpleBuyHold, []}  # Options passed to init/1
{ExPostFacto.ExampleStrategies.SmaStrategy, [fast_period: 5, slow_period: 10]}
{ExPostFacto.ExampleStrategies.AdvancedMacdStrategy, []}
```

**Key Differences:**

- **MFA strategies**: Simple functions that receive `(data, result)` and return an action
- **Strategy behavior**: Complex strategies with `init/1` and `next/1` callbacks, internal state, and helper functions

The reason some built-in strategies didn't work initially is because they use the Strategy behavior pattern (expecting options, not function calls), while our custom strategies use the simpler MFA pattern.

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
# Cell 9: Interactive Parameter Testing with Working Strategies
defmodule ParameterOptimizer do
  # Define multiple threshold strategies with different hardcoded values
  def threshold_strategy_2pct(%ExPostFacto.InputData{close: price}, %ExPostFacto.Result{is_position_open: is_position_open}) do
    threshold_strategy_with_multiplier(price, is_position_open, 0.02)
  end

  def threshold_strategy_4pct(%ExPostFacto.InputData{close: price}, %ExPostFacto.Result{is_position_open: is_position_open}) do
    threshold_strategy_with_multiplier(price, is_position_open, 0.04)
  end

  def threshold_strategy_6pct(%ExPostFacto.InputData{close: price}, %ExPostFacto.Result{is_position_open: is_position_open}) do
    threshold_strategy_with_multiplier(price, is_position_open, 0.06)
  end

  def threshold_strategy_8pct(%ExPostFacto.InputData{close: price}, %ExPostFacto.Result{is_position_open: is_position_open}) do
    threshold_strategy_with_multiplier(price, is_position_open, 0.08)
  end

  def threshold_strategy_10pct(%ExPostFacto.InputData{close: price}, %ExPostFacto.Result{is_position_open: is_position_open}) do
    threshold_strategy_with_multiplier(price, is_position_open, 0.10)
  end

  def threshold_strategy_12pct(%ExPostFacto.InputData{close: price}, %ExPostFacto.Result{is_position_open: is_position_open}) do
    threshold_strategy_with_multiplier(price, is_position_open, 0.12)
  end

  # Helper function that implements the actual strategy logic
  defp threshold_strategy_with_multiplier(price, is_position_open, threshold_multiplier) do
    avg_price = 100.0  # Base price from our data generator (starts at 100)
    buy_threshold = avg_price * (1.0 - threshold_multiplier)   # X% below average (buy low)
    sell_threshold = avg_price * (1.0 + threshold_multiplier)  # X% above average (sell high)

    cond do
      !is_position_open && price < buy_threshold ->
        :buy
      is_position_open && price > sell_threshold ->
        :close_buy
      true ->
        :noop
    end
  end

  def test_threshold_parameters(market_data) do
    # Map threshold multipliers to their corresponding function names
    strategy_functions = [
      {0.02, :threshold_strategy_2pct},
      {0.04, :threshold_strategy_4pct},
      {0.06, :threshold_strategy_6pct},
      {0.08, :threshold_strategy_8pct},
      {0.10, :threshold_strategy_10pct},
      {0.12, :threshold_strategy_12pct}
    ]

    results = for {multiplier, function_name} <- strategy_functions do
      # Use MFA format with the specific function for each threshold
      {:ok, result} = ExPostFacto.backtest(
        market_data,
        {ParameterOptimizer, function_name, []},
        starting_balance: 100_000.0
      )

      stats = ExPostFacto.Result.comprehensive_summary(result.result)

      %{
        threshold_pct: multiplier * 100,
        total_return: stats.total_return_pct,
        sharpe_ratio: stats.sharpe_ratio,
        win_rate: stats.win_rate,
        max_drawdown: stats.max_drawdown_pct,
        trade_count: length(result.result.trade_pairs)
      }
    end

    # Find best performing combination by Sharpe ratio
    best = if length(results) > 0 do
      Enum.max_by(results, & &1.sharpe_ratio)
    else
      %{threshold_pct: 0.0, total_return: 0.0, sharpe_ratio: 0.0, win_rate: 0.0, max_drawdown: 0.0, trade_count: 0}
    end

    {results, best}
  end
end

# Test different threshold sensitivities
{param_results, best_params} = ParameterOptimizer.test_threshold_parameters(
  market_data
)

IO.puts("=== Parameter Optimization Results ===")
IO.puts("Tested #{length(param_results)} threshold combinations")

# Show all results
IO.puts("\n📊 Threshold Sensitivity Analysis:")
for result <- param_results do
  IO.puts("±#{result.threshold_pct}%: Return #{Float.round(result.total_return * 1.0, 1)}%, Sharpe #{Float.round(result.sharpe_ratio * 1.0, 2)}, Trades #{result.trade_count}, Win Rate #{Float.round(result.win_rate * 1.0, 1)}%")
end

IO.puts("\n🏆 Best Threshold: ±#{best_params.threshold_pct}%")
IO.puts("📈 Sharpe Ratio: #{Float.round(best_params.sharpe_ratio * 1.0, 3)}")
IO.puts("💰 Total Return: #{Float.round(best_params.total_return * 1.0, 2)}%")
IO.puts("🎯 Win Rate: #{Float.round(best_params.win_rate * 1.0, 2)}%")
IO.puts("📉 Max Drawdown: #{Float.round(best_params.max_drawdown * 1.0, 2)}%")
IO.puts("🔄 Total Trades: #{best_params.trade_count}")
```

### Real-time Strategy Testing

```elixir
# Cell 10: Interactive Strategy Form
defmodule InteractiveStrategy do
  # Create multiple threshold strategies for common percentages
  def threshold_1pct(%ExPostFacto.InputData{close: price}, %ExPostFacto.Result{is_position_open: is_position_open}) do
    threshold_logic(price, is_position_open, 0.01)
  end

  def threshold_2pct(%ExPostFacto.InputData{close: price}, %ExPostFacto.Result{is_position_open: is_position_open}) do
    threshold_logic(price, is_position_open, 0.02)
  end

  def threshold_3pct(%ExPostFacto.InputData{close: price}, %ExPostFacto.Result{is_position_open: is_position_open}) do
    threshold_logic(price, is_position_open, 0.03)
  end

  def threshold_4pct(%ExPostFacto.InputData{close: price}, %ExPostFacto.Result{is_position_open: is_position_open}) do
    threshold_logic(price, is_position_open, 0.04)
  end

  def threshold_5pct(%ExPostFacto.InputData{close: price}, %ExPostFacto.Result{is_position_open: is_position_open}) do
    threshold_logic(price, is_position_open, 0.05)
  end

  def threshold_6pct(%ExPostFacto.InputData{close: price}, %ExPostFacto.Result{is_position_open: is_position_open}) do
    threshold_logic(price, is_position_open, 0.06)
  end

  def threshold_8pct(%ExPostFacto.InputData{close: price}, %ExPostFacto.Result{is_position_open: is_position_open}) do
    threshold_logic(price, is_position_open, 0.08)
  end

  def threshold_10pct(%ExPostFacto.InputData{close: price}, %ExPostFacto.Result{is_position_open: is_position_open}) do
    threshold_logic(price, is_position_open, 0.10)
  end

  def threshold_12pct(%ExPostFacto.InputData{close: price}, %ExPostFacto.Result{is_position_open: is_position_open}) do
    threshold_logic(price, is_position_open, 0.12)
  end

  def threshold_15pct(%ExPostFacto.InputData{close: price}, %ExPostFacto.Result{is_position_open: is_position_open}) do
    threshold_logic(price, is_position_open, 0.15)
  end

  def threshold_20pct(%ExPostFacto.InputData{close: price}, %ExPostFacto.Result{is_position_open: is_position_open}) do
    threshold_logic(price, is_position_open, 0.20)
  end

  # Helper function that implements the actual strategy logic
  defp threshold_logic(price, is_position_open, threshold_multiplier) do
    avg_price = 100.0  # Base price (data starts at 100)
    buy_threshold = avg_price * (1.0 - threshold_multiplier)  # Buy low
    sell_threshold = avg_price * (1.0 + threshold_multiplier) # Sell high

    cond do
      !is_position_open && price < buy_threshold ->
        :buy
      is_position_open && price > sell_threshold ->
        :close_buy
      true ->
        :noop
    end
  end

  # Function to select the appropriate strategy function based on threshold percentage
  def get_strategy_function(threshold_pct) do
    case threshold_pct do
      x when x <= 1.5 -> :threshold_1pct
      x when x <= 2.5 -> :threshold_2pct
      x when x <= 3.5 -> :threshold_3pct
      x when x <= 4.5 -> :threshold_4pct
      x when x <= 5.5 -> :threshold_5pct
      x when x <= 7.0 -> :threshold_6pct
      x when x <= 9.0 -> :threshold_8pct
      x when x <= 11.0 -> :threshold_10pct
      x when x <= 13.5 -> :threshold_12pct
      x when x <= 17.5 -> :threshold_15pct
      _ -> :threshold_20pct
    end
  end
end

form =
  Kino.Control.form([
    threshold_pct: Kino.Input.number("Threshold Percentage", default: 6.0),
    initial_balance: Kino.Input.number("Starting Balance", default: 100_000)
  ], submit: "Run Backtest")

Kino.Control.stream(form)
|> Kino.listen(fn %{data: %{threshold_pct: threshold, initial_balance: balance}} ->
  if threshold > 0 and threshold <= 20 do
    # Get the appropriate strategy function for this threshold
    strategy_function = InteractiveStrategy.get_strategy_function(threshold)

    {:ok, result} = ExPostFacto.backtest(
      market_data,
      {InteractiveStrategy, strategy_function, []},
      starting_balance: balance
    )

    stats = ExPostFacto.Result.comprehensive_summary(result.result)

    IO.puts("\n=== Custom Strategy Results ===")
    IO.puts("Threshold: ±#{threshold}% (using #{strategy_function})")
    IO.puts("Starting Balance: $#{balance}")
    IO.puts("Final Balance: $#{Float.round(stats.final_balance * 1.0, 2)}")
    IO.puts("Total Return: #{Float.round(stats.total_return_pct * 1.0, 2)}%")
    IO.puts("Sharpe Ratio: #{Float.round(stats.sharpe_ratio * 1.0, 3)}")
    IO.puts("Win Rate: #{Float.round(stats.win_rate * 1.0, 2)}%")
    IO.puts("Max Drawdown: #{Float.round(stats.max_drawdown_pct * 1.0, 2)}%")
    IO.puts("Total Trades: #{length(result.result.trade_pairs)}")
  else
    IO.puts("Error: Threshold must be between 0% and 20%")
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
