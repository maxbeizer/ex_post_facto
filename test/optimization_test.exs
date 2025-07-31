defmodule ExPostFacto.OptimizationTest do
  @moduledoc """
  Tests for optimization functionality that require strategy behaviour modules.

  These tests are run sequentially (async: false) to avoid conflicts with
  the StrategyContext GenServer singleton.
  """

  use ExUnit.Case, async: false
  import CandleDataHelper

  describe "optimize/4" do
    test "performs grid search optimization successfully" do
      data = generate_trending_test_data(30)

      {:ok, result} =
        ExPostFacto.optimize(
          data,
          ExPostFacto.ExampleStrategies.SmaStrategy,
          [fast_period: 5..7, slow_period: 15..17],
          maximize: :total_return_pct
        )

      assert result.method == :grid_search
      assert result.metric == :total_return_pct
      assert is_list(result.best_params)
      assert is_number(result.best_score)
      # 3 x 3 combinations
      assert length(result.all_results) == 9
    end

    test "performs random search optimization successfully" do
      data = generate_trending_test_data(25)

      {:ok, result} =
        ExPostFacto.optimize(
          data,
          ExPostFacto.ExampleStrategies.SmaStrategy,
          [fast_period: 5..10, slow_period: 15..25],
          method: :random_search,
          samples: 8,
          maximize: :sharpe_ratio
        )

      assert result.method == :random_search
      assert result.metric == :sharpe_ratio
      assert length(result.all_results) == 8
    end

    test "returns error for unsupported optimization method" do
      data = [build_candle(open: 10.0, close: 10.5)]

      {:error, message} =
        ExPostFacto.optimize(
          data,
          ExPostFacto.ExampleStrategies.SmaStrategy,
          [fast_period: [5], slow_period: [15]],
          method: :genetic_algorithm
        )

      assert String.contains?(message, "Unsupported optimization method")
    end

    test "uses default optimization settings when not specified" do
      data = generate_trending_test_data(20)

      {:ok, result} =
        ExPostFacto.optimize(
          data,
          ExPostFacto.ExampleStrategies.SmaStrategy,
          fast_period: [5],
          slow_period: [15]
        )

      # Should default to grid search and sharpe_ratio
      assert result.method == :grid_search
      assert result.metric == :sharpe_ratio
    end

    test "performs walk-forward optimization successfully" do
      data = generate_trending_test_data(150)

      {:ok, result} =
        ExPostFacto.optimize(
          data,
          ExPostFacto.ExampleStrategies.SmaStrategy,
          [fast_period: [5, 7], slow_period: [15, 20]],
          method: :walk_forward,
          training_window: 40,
          validation_window: 20,
          step_size: 15
        )

      assert result.method == :walk_forward
      assert Map.has_key?(result, :windows)
      assert Map.has_key?(result, :summary)
      assert Map.has_key?(result, :parameters_stability)
    end
  end

  describe "heatmap/3" do
    test "generates heatmap from optimization results" do
      data = generate_trending_test_data(25)

      {:ok, opt_result} =
        ExPostFacto.optimize(
          data,
          ExPostFacto.ExampleStrategies.SmaStrategy,
          [fast_period: 5..7, slow_period: 15..17],
          method: :grid_search
        )

      {:ok, heatmap} = ExPostFacto.heatmap(opt_result, :fast_period, :slow_period)

      assert heatmap.x_param == :fast_period
      assert heatmap.y_param == :slow_period
      assert is_list(heatmap.x_values)
      assert is_list(heatmap.y_values)
      assert is_list(heatmap.scores)
    end

    test "returns error for invalid heatmap parameters" do
      data = generate_trending_test_data(15)

      {:ok, opt_result} =
        ExPostFacto.optimize(
          data,
          ExPostFacto.ExampleStrategies.SmaStrategy,
          [fast_period: [5], slow_period: [15]],
          method: :grid_search
        )

      {:error, message} = ExPostFacto.heatmap(opt_result, :fast_period, :fast_period)
      assert String.contains?(message, "must be different")

      {:error, message} = ExPostFacto.heatmap(opt_result, :nonexistent_param, :slow_period)
      assert String.contains?(message, "not found")
    end
  end

  # Helper function to generate test data with a trend
  defp generate_trending_test_data(count) do
    1..count
    |> Enum.map(fn i ->
      # Create an upward trending price pattern
      base_price = 100.0 + i * 0.5
      noise = (:rand.uniform() - 0.5) * 2

      build_candle(
        open: base_price + noise,
        high: base_price + abs(noise) + 1,
        low: base_price - abs(noise) - 1,
        close: base_price + noise * 0.5,
        timestamp: "2023-01-#{rem(i - 1, 28) + 1}"
      )
    end)
  end
end
