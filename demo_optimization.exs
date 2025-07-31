#!/usr/bin/env elixir

# Parameter Optimization Framework Demo
# This script demonstrates the key features of the ExPostFacto optimization framework

IO.puts("=== ExPostFacto Parameter Optimization Framework Demo ===\n")

# Generate sample market data (trending upward with some volatility)
generate_sample_data = fn count ->
  Enum.map(1..count, fn i ->
    base_price = 10.0 + i * 0.05  # Upward trend
    volatility = (:rand.uniform() - 0.5) * 0.2  # Random volatility
    price = base_price + volatility
    
    open = price
    close = price + 0.03 + volatility * 0.3
    high = max(open, close) + abs(volatility) * 0.5
    low = min(open, close) - abs(volatility) * 0.5
    
    %{open: open, close: close, high: high, low: low, timestamp: "#{i}"}
  end)
end

sample_data = generate_sample_data.(100)
IO.puts("Generated #{length(sample_data)} data points for optimization")

# Define a simple strategy module for demonstration
defmodule DemoStrategy do
  @moduledoc "Simple SMA crossover strategy for demonstration"
  
  use ExPostFacto.Strategy
  
  def init(opts) do
    fast_period = Keyword.get(opts, :fast_period, 10)
    slow_period = Keyword.get(opts, :slow_period, 20)
    
    if fast_period >= slow_period do
      {:error, "fast_period must be less than slow_period"}
    else
      {:ok, %{
        fast_period: fast_period,
        slow_period: slow_period,
        price_history: []
      }}
    end
  end
  
  def next(state) do
    current_price = data().close
    updated_history = [current_price | state.price_history]
    
    # Calculate SMAs
    fast_sma = calculate_sma(updated_history, state.fast_period)
    slow_sma = calculate_sma(updated_history, state.slow_period)
    
    # Simple crossover logic
    if fast_sma > slow_sma and length(updated_history) >= state.slow_period do
      buy()
    end
    
    {:ok, %{state | price_history: Enum.take(updated_history, 50)}}
  end
  
  defp calculate_sma(prices, period) do
    if length(prices) >= period do
      prices |> Enum.take(period) |> Enum.sum() |> Kernel./(period)
    else
      0.0
    end
  end
end

IO.puts("\n=== 1. Grid Search Optimization ===")

# Demonstrate grid search optimization
grid_search_demo = fn ->
  try do
    param_ranges = [
      fast_period: 5..8,
      slow_period: 15..18
    ]
    
    IO.puts("Parameter ranges: #{inspect(param_ranges)}")
    IO.puts("This will test #{4 * 4} parameter combinations")
    
    # Note: This would work with the full ExPostFacto system
    IO.puts("Grid search would optimize across all combinations and return:")
    IO.puts("- Best parameters found")
    IO.puts("- Best performance score")
    IO.puts("- All tested combinations with their scores")
    IO.puts("- Method: :grid_search")
  rescue
    e -> IO.puts("Demo simulation (would require full ExPostFacto): #{Exception.message(e)}")
  end
end

grid_search_demo.()

IO.puts("\n=== 2. Random Search Optimization ===")

# Demonstrate random search optimization
random_search_demo = fn ->
  IO.puts("Parameter ranges: fast_period: 5..15, slow_period: 20..30")
  IO.puts("Random samples: 20")
  IO.puts("Random search would:")
  IO.puts("- Randomly sample 20 parameter combinations")
  IO.puts("- Test each combination")
  IO.puts("- Return the best performing parameters")
  IO.puts("- Method: :random_search")
end

random_search_demo.()

IO.puts("\n=== 3. Walk-Forward Analysis ===")

# Demonstrate walk-forward analysis
walk_forward_demo = fn ->
  IO.puts("Training window: 40 data points")
  IO.puts("Validation window: 20 data points")
  IO.puts("Step size: 15 data points")
  IO.puts("Walk-forward analysis would:")
  IO.puts("- Optimize parameters on each training window")
  IO.puts("- Test on the following validation window")
  IO.puts("- Provide parameter stability analysis")
  IO.puts("- Show performance consistency over time")
end

walk_forward_demo.()

IO.puts("\n=== 4. Parameter Heatmap ===")

# Demonstrate heatmap generation
heatmap_demo = fn ->
  IO.puts("For 2-parameter optimization (fast_period vs slow_period):")
  IO.puts("Heatmap would provide:")
  IO.puts("- X-axis values: [5, 6, 7, 8]")
  IO.puts("- Y-axis values: [15, 16, 17, 18]")
  IO.puts("- Score matrix: 4x4 grid of performance scores")
  IO.puts("- Visualization data for parameter space analysis")
end

heatmap_demo.()

IO.puts("\n=== API Usage Examples ===")

api_examples = """
# Grid search optimization
{:ok, results} = ExPostFacto.optimize(
  market_data,
  MyStrategy,
  [fast: 5..20, slow: 20..50],
  maximize: :sharpe_ratio
)

# Random search with custom settings
{:ok, results} = ExPostFacto.optimize(
  market_data,
  MyStrategy,
  [fast: 5..20, slow: 20..50],
  method: :random_search,
  samples: 100,
  maximize: :total_return_pct
)

# Walk-forward analysis
{:ok, results} = ExPostFacto.optimize(
  market_data,
  MyStrategy,
  [fast: 5..15, slow: 20..40],
  method: :walk_forward,
  training_window: 100,
  validation_window: 50
)

# Generate parameter heatmap
{:ok, heatmap} = ExPostFacto.heatmap(results, :fast, :slow)

# Access results
IO.puts("Best parameters: \#{inspect(results.best_params)}")
IO.puts("Best score: \#{results.best_score}")
IO.puts("Optimization method: \#{results.method}")
"""

IO.puts(api_examples)

IO.puts("\n=== Supported Optimization Metrics ===")

metrics_info = """
- :sharpe_ratio - Risk-adjusted return (Sharpe ratio)
- :total_return_pct - Total percentage return
- :cagr_pct - Compound Annual Growth Rate
- :profit_factor - Gross profit / gross loss ratio
- :sqn - System Quality Number
- :win_rate - Percentage of winning trades
- :max_draw_down_percentage - Maximum drawdown (minimized)
"""

IO.puts(metrics_info)

IO.puts("\n=== Framework Features ===")

features = """
✓ Grid search optimization with configurable limits
✓ Random search with customizable sample sizes
✓ Walk-forward analysis for robustness testing
✓ Parameter heatmap generation for visualization
✓ Multiple optimization metrics support
✓ Comprehensive error handling
✓ Strategy parameter stability analysis
✓ Professional-grade backtesting integration

The optimization framework is production-ready and integrates
seamlessly with the existing ExPostFacto backtesting system.
"""

IO.puts(features)

IO.puts("\n=== Demo Complete ===")