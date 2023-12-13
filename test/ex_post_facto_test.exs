defmodule ExPostFactoTest do
  use ExUnit.Case, async: true
  doctest ExPostFacto

  alias ExPostFacto.ExampleStrategies.{
    BuyBuyBuy,
    Noop
  }

  alias ExPostFacto.{
    Output,
    Result
  }

  test "backtest/3 returns an error when data is nil" do
    assert {:error, "data cannot be nil"} = ExPostFacto.backtest(nil, {Noop, :noop, []})
  end

  test "backtest/3 returns an error when strategy is nil" do
    assert {:error, "strategy cannot be nil"} = ExPostFacto.backtest([], nil)
  end

  test "backtest/3 returns an output struct" do
    assert {:ok, %Output{}} = ExPostFacto.backtest([], {Noop, :noop, []})
  end

  test "backtest/3 returns an output struct with the data" do
    example_data = [%{high: 1.0, low: 0.0, open: 0.25, close: 0.75}]

    {:ok, output} = ExPostFacto.backtest(example_data, {Noop, :noop, []})

    assert example_data == output.data
  end

  test "backtest/3 returns an output struct with the strategy" do
    example_data = [%{high: 1.0, low: 0.0, open: 0.25, close: 0.75}]
    mfa = {Noop, :noop, []}

    {:ok, output} = ExPostFacto.backtest(example_data, mfa)

    assert mfa == output.strategy
  end

  test "backtest/3 returns an output struct with the result struct" do
    example_data = [%{high: 1.0, low: 0.0, open: 0.25, close: 0.75}]
    mfa = {Noop, :noop, []}

    {:ok, output} = ExPostFacto.backtest(example_data, mfa)

    assert %Result{} == output.result
  end

  test "backtest/3 collects data points from the applied strategy" do
    example_data = [%{high: 1.0, low: 0.0, open: 0.25, close: 0.75}]
    mfa = {BuyBuyBuy, :call, []}
    expected_data_points = [%{index: 0, action: :buy, datum: hd(example_data)}]

    {:ok, %{result: result}} = ExPostFacto.backtest(example_data, mfa)

    assert expected_data_points == result.data_points
  end
end
