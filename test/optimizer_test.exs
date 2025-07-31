defmodule ExPostFacto.OptimizerTest do
  use ExUnit.Case
  import CandleDataHelper

  alias ExPostFacto.{Optimizer, Output}
  alias ExPostFacto.ExampleStrategies.SmaStrategy

  describe "grid_search/4" do
    test "optimizes SMA strategy parameters successfully" do
      # Generate test data with trend to give SMA strategy something to work with
      data = generate_trending_data(50, 10.0, 0.1)

      # Define small parameter ranges for testing
      param_ranges = [
        fast_period: 5..7,
        slow_period: 15..17
      ]

      opts = [
        maximize: :total_return_pct,
        starting_balance: 10_000.0
      ]

      {:ok, result} = Optimizer.grid_search(data, SmaStrategy, param_ranges, opts)

      # Verify result structure
      assert is_map(result)
      assert Map.has_key?(result, :best_params)
      assert Map.has_key?(result, :best_score)
      assert Map.has_key?(result, :best_output)
      assert Map.has_key?(result, :all_results)
      assert Map.has_key?(result, :method)
      assert Map.has_key?(result, :metric)

      # Verify result content
      assert result.method == :grid_search
      assert result.metric == :total_return_pct
      assert is_list(result.best_params)
      assert is_number(result.best_score)
      assert %Output{} = result.best_output
      
      # Should have tested all combinations (3 x 3 = 9)
      assert length(result.all_results) == 9
      
      # Best params should be within the specified ranges
      fast_period = Keyword.get(result.best_params, :fast_period)
      slow_period = Keyword.get(result.best_params, :slow_period)
      assert fast_period in 5..7
      assert slow_period in 15..17
    end

    test "handles empty parameter ranges" do
      data = generate_simple_data(10)
      param_ranges = []
      
      {:ok, result} = Optimizer.grid_search(data, SmaStrategy, param_ranges, [])
      
      # Should return result with default parameters
      assert length(result.all_results) == 1
      assert result.best_params == []
    end

    test "returns error for too many parameter combinations" do
      data = generate_simple_data(10)
      
      # Large parameter ranges that exceed max_combinations
      param_ranges = [
        fast_period: 1..50,
        slow_period: 51..100
      ]
      
      opts = [max_combinations: 100]  # 50 * 50 = 2500 > 100
      
      {:error, message} = Optimizer.grid_search(data, SmaStrategy, param_ranges, opts)
      assert String.contains?(message, "Too many parameter combinations")
    end

    test "handles strategy initialization errors gracefully" do
      data = generate_simple_data(10)
      
      # Invalid parameters that will cause strategy init to fail
      param_ranges = [
        fast_period: [20],  # fast >= slow will cause error
        slow_period: [10]
      ]
      
      {:ok, result} = Optimizer.grid_search(data, SmaStrategy, param_ranges, [])
      
      # Should handle failed backtests gracefully
      assert length(result.all_results) == 1
      failed_result = hd(result.all_results)
      assert failed_result.score == nil
      assert failed_result.output == nil
    end

    test "supports different optimization metrics" do
      data = generate_trending_data(30, 10.0, 0.05)
      param_ranges = [fast_period: [5], slow_period: [15]]
      
      metrics = [:sharpe_ratio, :total_return_pct, :cagr_pct, :profit_factor, :win_rate]
      
      for metric <- metrics do
        {:ok, result} = Optimizer.grid_search(data, SmaStrategy, param_ranges, maximize: metric)
        assert result.metric == metric
        assert is_number(result.best_score)
      end
    end
  end

  describe "random_search/4" do
    test "optimizes SMA strategy parameters with random sampling" do
      data = generate_trending_data(50, 10.0, 0.1)

      param_ranges = [
        fast_period: 5..10,
        slow_period: 15..25
      ]

      opts = [
        maximize: :total_return_pct,
        samples: 10,
        starting_balance: 10_000.0
      ]

      {:ok, result} = Optimizer.random_search(data, SmaStrategy, param_ranges, opts)

      # Verify result structure
      assert result.method == :random_search
      assert result.metric == :total_return_pct
      assert is_list(result.best_params)
      assert is_number(result.best_score)
      assert %Output{} = result.best_output
      
      # Should have tested the specified number of samples
      assert length(result.all_results) == 10
      
      # Best params should be within the specified ranges
      fast_period = Keyword.get(result.best_params, :fast_period)
      slow_period = Keyword.get(result.best_params, :slow_period)
      assert fast_period in 5..10
      assert slow_period in 15..25
    end

    test "handles list-based parameter ranges" do
      data = generate_simple_data(20)
      
      param_ranges = [
        fast_period: [3, 5, 7, 9],
        slow_period: [15, 20, 25]
      ]
      
      opts = [samples: 5]
      
      {:ok, result} = Optimizer.random_search(data, SmaStrategy, param_ranges, opts)
      
      assert length(result.all_results) == 5
      
      # Check that selected parameters are from the provided lists
      for %{params: params} <- result.all_results do
        fast_period = Keyword.get(params, :fast_period)
        slow_period = Keyword.get(params, :slow_period)
        assert fast_period in [3, 5, 7, 9]
        assert slow_period in [15, 20, 25]
      end
    end

    test "handles single-value parameter ranges" do
      data = generate_simple_data(15)
      
      param_ranges = [
        fast_period: 5,  # Single value, not a range
        slow_period: [20]  # List with single value
      ]
      
      {:ok, result} = Optimizer.random_search(data, SmaStrategy, param_ranges, samples: 3)
      
      # All results should have the same parameters
      for %{params: params} <- result.all_results do
        assert Keyword.get(params, :fast_period) == 5
        assert Keyword.get(params, :slow_period) == 20
      end
    end
  end

  # Helper functions for generating test data

  defp generate_simple_data(count) do
    Enum.map(1..count, fn i ->
      price = 10.0 + i * 0.1
      build_candle(open: price, close: price, high: price + 0.05, low: price - 0.05)
    end)
  end

  defp generate_trending_data(count, start_price, trend) do
    Enum.map(1..count, fn i ->
      base_price = start_price + i * trend
      # Add some randomness
      random_factor = (:rand.uniform() - 0.5) * 0.1
      price = base_price + random_factor
      
      open = price
      close = price + trend * 0.5 + random_factor * 0.5
      high = max(open, close) + abs(random_factor)
      low = min(open, close) - abs(random_factor)
      
      build_candle(open: open, close: close, high: high, low: low)
    end)
  end

  describe "heatmap/3" do
    test "generates heatmap data from grid search results" do
      data = generate_trending_data(30, 10.0, 0.05)

      param_ranges = [
        fast_period: 5..7,
        slow_period: 15..17
      ]

      {:ok, optimization_result} = Optimizer.grid_search(data, SmaStrategy, param_ranges, [])
      {:ok, heatmap} = Optimizer.heatmap(optimization_result, :fast_period, :slow_period)

      # Verify heatmap structure
      assert Map.has_key?(heatmap, :x_values)
      assert Map.has_key?(heatmap, :y_values)
      assert Map.has_key?(heatmap, :scores)
      assert Map.has_key?(heatmap, :x_param)
      assert Map.has_key?(heatmap, :y_param)

      # Verify content
      assert heatmap.x_param == :fast_period
      assert heatmap.y_param == :slow_period
      assert heatmap.x_values == [5, 6, 7]
      assert heatmap.y_values == [15, 16, 17]
      
      # Should have 3x3 score matrix
      assert length(heatmap.scores) == 3
      assert Enum.all?(heatmap.scores, fn row -> length(row) == 3 end)
    end

    test "returns error for invalid parameters" do
      data = generate_simple_data(10)
      {:ok, result} = Optimizer.grid_search(data, SmaStrategy, [fast_period: [5], slow_period: [15]], [])

      # Same parameter for both axes
      {:error, message} = Optimizer.heatmap(result, :fast_period, :fast_period)
      assert String.contains?(message, "X and Y parameters must be different")

      # Non-existent parameter
      {:error, message} = Optimizer.heatmap(result, :fast_period, :non_existent)
      assert String.contains?(message, "not found in optimization results")
    end
  end

  describe "walk_forward/4" do
    test "performs walk-forward analysis successfully" do
      # Generate enough data for walk-forward analysis
      data = generate_trending_data(200, 10.0, 0.02)

      param_ranges = [
        fast_period: [5, 7],
        slow_period: [15, 20]
      ]

      opts = [
        training_window: 50,
        validation_window: 25,
        step_size: 25,
        maximize: :total_return_pct
      ]

      {:ok, result} = Optimizer.walk_forward(data, SmaStrategy, param_ranges, opts)

      # Verify result structure
      assert Map.has_key?(result, :windows)
      assert Map.has_key?(result, :summary)
      assert Map.has_key?(result, :parameters_stability)
      assert result.method == :walk_forward

      # Should have multiple windows
      assert length(result.windows) > 1

      # Verify summary structure
      summary = result.summary
      assert Map.has_key?(summary, :total_windows)
      assert Map.has_key?(summary, :valid_windows)
      assert Map.has_key?(summary, :average_validation_score)

      # Verify stability analysis
      stability = result.parameters_stability
      assert Map.has_key?(stability, :parameter_stability)
      assert Map.has_key?(stability, :overall_stability)
    end

    test "returns error for insufficient data" do
      data = generate_simple_data(50)  # Not enough for default windows

      {:error, message} = Optimizer.walk_forward(data, SmaStrategy, [fast_period: [5]], [])
      assert String.contains?(message, "Insufficient data")
    end

    test "handles custom window configurations" do
      data = generate_trending_data(100, 10.0, 0.03)

      opts = [
        training_window: 20,
        validation_window: 10,
        step_size: 10
      ]

      {:ok, result} = Optimizer.walk_forward(data, SmaStrategy, [fast_period: [5], slow_period: [15]], opts)

      # Should have windows based on the step size
      expected_windows = (100 - 30) ÷ 10 + 1  # (data_length - window_size) / step_size + 1
      assert length(result.windows) == expected_windows
    end
  end
end