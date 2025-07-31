defmodule ExPostFactoTest do
  use ExUnit.Case, async: true
  doctest ExPostFacto
  import CandleDataHelper

  alias ExPostFacto.ExampleStrategies.{
    BuyBuyBuy,
    SellSellSell,
    Noop
  }

  alias ExPostFacto.{DataPoint, InputData}

  alias ExPostFacto.{
    DataPoint,
    InputData,
    Output,
    Result
  }

  @basic_data_point [%{o: 1.0, h: 2.0, l: 0.5, c: 1.0}]

  test "backtest/3 returns an error when data is nil" do
    assert {:error, "data cannot be nil"} = ExPostFacto.backtest(nil, {Noop, :noop, []})
  end

  test "backtest/3 returns an error when data is empty" do
    assert {:error, "data cannot be empty"} = ExPostFacto.backtest([], {Noop, :noop, []})
  end

  test "backtest/3 returns an error when strategy is nil" do
    assert {:error, "strategy cannot be nil"} = ExPostFacto.backtest(@basic_data_point, nil)
  end

  test "backtest/3 returns an output struct" do
    assert {:ok, %Output{}} = ExPostFacto.backtest(@basic_data_point, {Noop, :noop, []})
  end

  test "backtest/3 returns an initial starting balance of 0.0 if not specified" do
    {:ok, %{result: result}} = ExPostFacto.backtest(@basic_data_point, {Noop, :noop, []})

    assert 0.0 == result.starting_balance
  end

  test "backtest/3 allows passing in of an initial starting_balance" do
    {:ok, %{result: result}} =
      ExPostFacto.backtest(@basic_data_point, {Noop, :noop, []}, starting_balance: 100.0)

    assert 100.0 == result.starting_balance
  end

  test "backtest/3 returns an output struct with the data" do
    example_data = [build_candle(open: 0.75)]

    {:ok, output} = ExPostFacto.backtest(example_data, {Noop, :noop, []}, validate_data: false)

    assert example_data == output.data
  end

  test "backtest/3 returns an output struct with the strategy" do
    example_data = [%{high: 1.0, low: 0.0, open: 0.25, close: 0.75}]
    mfa = {Noop, :noop, []}

    {:ok, output} = ExPostFacto.backtest(example_data, mfa, validate_data: false)

    assert mfa == output.strategy
  end

  test "backtest/3 returns an output struct with the result struct" do
    example_data = [%{high: 1.0, low: 0.0, open: 0.25, close: 0.75}]
    mfa = {Noop, :noop, []}

    {:ok, output} = ExPostFacto.backtest(example_data, mfa, validate_data: false)

    assert %Result{} = output.result
    # Should have comprehensive stats calculated
    assert is_float(output.result.total_return_pct)
    assert is_binary(output.result.sqn_interpretation)
    assert is_binary(output.result.kelly_interpretation)
  end

  test "backtest/3 collects data points from the applied strategy" do
    mfa = {BuyBuyBuy, :call, []}

    example_data = [
      build_candle(open: 0.75, timestamp: "2023-01-01"),
      build_candle(open: 0.80, timestamp: "2023-01-02")
    ]

    {:ok, %{result: result}} = ExPostFacto.backtest(example_data, mfa, validate_data: false)

    # With 2 data points, MFA strategy gets called once with data from index 0,
    # and creates a data point at index 1 (using the second data point)
    expected_data_points = [
      %DataPoint{
        datum: %InputData{
          high: 1.0,
          low: 0.80,
          open: 0.80,
          close: 1.0,
          volume: nil,
          timestamp: ~U[2023-01-02 00:00:00Z],
          other: nil
        },
        action: :buy,
        index: 1
      }
    ]

    assert expected_data_points == result.data_points
  end

  test "backtest/3 handles P&L when there are open positions" do
    example_data = [
      build_candle(open: 0.75)
    ]

    {:ok, %{result: result}} =
      ExPostFacto.backtest(example_data, {BuyBuyBuy, :call, []}, validate_data: false)

    assert 0.0 == result.total_profit_and_loss
  end

  test "backtest/3 collects P&L from the applied strategy when positive" do
    example_data = [
      build_candle(open: 0.75),
      build_candle(open: 0.75),
      build_candle(:close_buy, open: 1.75),
      build_candle(:close_buy, open: 1.75)
    ]

    mfa = {BuyBuyBuy, :call, []}

    {:ok, %{result: result}} = ExPostFacto.backtest(example_data, mfa, validate_data: false)

    # 1.75 - 0.75 = 1.0
    assert 1.0 == result.total_profit_and_loss
  end

  test "backtest/3 collects P&L from the applied strategy when negative" do
    example_data = [
      build_candle(open: 1.75),
      build_candle(open: 1.75),
      build_candle(:close_buy, open: 0.75),
      build_candle(:close_buy, open: 0.75)
    ]

    mfa = {BuyBuyBuy, :call, []}

    {:ok, %{result: result}} = ExPostFacto.backtest(example_data, mfa, validate_data: false)

    # 0.75 - 1.75 = -1.0
    assert -1.0 == result.total_profit_and_loss
  end

  test "backtest/3 handles multiple buy profit points" do
    example_data = [
      build_candle(open: 0.75),
      build_candle(open: 0.75),
      build_candle(:close_buy, open: 1.75),
      build_candle(:close_buy, open: 1.75),
      build_candle(open: 0.75),
      build_candle(open: 0.75),
      build_candle(:close_buy, open: 1.75),
      build_candle(:close_buy, open: 1.75)
    ]

    mfa = {BuyBuyBuy, :call, []}

    {:ok, %{result: result}} = ExPostFacto.backtest(example_data, mfa, validate_data: false)

    # 2 * (1.75 - 0.75) = 2.0
    assert 2.0 == result.total_profit_and_loss
  end

  test "backtest/3 handles multiple buy loss points" do
    example_data = [
      build_candle(open: 1.75),
      build_candle(open: 1.75),
      build_candle(:close_buy, open: 0.75),
      build_candle(:close_buy, open: 0.75),
      build_candle(open: 1.75),
      build_candle(open: 1.75),
      build_candle(:close_buy, open: 0.75),
      build_candle(:close_buy, open: 0.75)
    ]

    mfa = {BuyBuyBuy, :call, []}

    {:ok, %{result: result}} = ExPostFacto.backtest(example_data, mfa, validate_data: false)

    # 2 * (1.75 - 0.75) = -2.0
    assert -2.0 == result.total_profit_and_loss
  end

  test "backtest/3 handles sells for profit" do
    example_data = [
      build_candle(open: 1.75),
      build_candle(open: 1.75),
      build_candle(:close_sell, open: 0.75),
      build_candle(:close_sell, open: 0.75)
    ]

    mfa = {SellSellSell, :call, []}

    {:ok, %{result: result}} = ExPostFacto.backtest(example_data, mfa, validate_data: false)

    # 1.75 + 0.75 = 1.0
    assert 1.0 == result.total_profit_and_loss
  end

  test "backtest/3 handles sells for loss" do
    example_data = [
      build_candle(open: 0.25),
      build_candle(open: 0.25),
      build_candle(:close_sell, open: 1.25),
      build_candle(:close_sell, open: 1.25)
    ]

    mfa = {SellSellSell, :call, []}

    {:ok, %{result: result}} = ExPostFacto.backtest(example_data, mfa, validate_data: false)

    # 0.75 - 1.75 = -1.0
    assert -1.0 == result.total_profit_and_loss
  end

  test "backtest/3 handles multiple sell profit points" do
    example_data = [
      build_candle(open: 1.75),
      build_candle(open: 1.75),
      build_candle(:close_sell, open: 0.75),
      build_candle(:close_sell, open: 0.75),
      build_candle(open: 1.75),
      build_candle(open: 1.75),
      build_candle(:close_sell, open: 0.75),
      build_candle(:close_sell, open: 0.75)
    ]

    mfa = {SellSellSell, :call, []}

    {:ok, %{result: result}} = ExPostFacto.backtest(example_data, mfa, validate_data: false)

    # 2 * (1.75 - 0.75) = 2.0
    assert 2.0 == result.total_profit_and_loss
  end

  test "backtest/3 handles multiple sell loss points" do
    example_data = [
      build_candle(open: 0.75),
      build_candle(open: 0.75),
      build_candle(:close_sell, open: 1.75),
      build_candle(:close_sell, open: 1.75),
      build_candle(open: 0.75),
      build_candle(open: 0.75),
      build_candle(:close_sell, open: 1.75),
      build_candle(:close_sell, open: 1.75)
    ]

    mfa = {SellSellSell, :call, []}

    {:ok, %{result: result}} = ExPostFacto.backtest(example_data, mfa, validate_data: false)

    # 2 * (1.75 - 0.75) = -2.0
    assert -2.0 == result.total_profit_and_loss
  end

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
          fast_period: [5],
          slow_period: [15]
        )

      {:error, message} = ExPostFacto.heatmap(opt_result, :invalid_param, :slow_period)
      assert String.contains?(message, "not found in optimization results")
    end
  end

  # Helper function to generate trending test data
  defp generate_trending_test_data(count) do
    Enum.map(1..count, fn i ->
      base_price = 10.0 + i * 0.1
      random_offset = (:rand.uniform() - 0.5) * 0.05
      price = base_price + random_offset

      build_candle(
        open: price,
        close: price + 0.05 + random_offset,
        high: price + 0.1,
        low: price - 0.05
      )
    end)
  end
end
