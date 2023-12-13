defmodule ExPostFactoTest do
  use ExUnit.Case, async: true
  doctest ExPostFacto

  alias ExPostFacto.ExampleStrategies.{
    BuyBuyBuy,
    SellSellSell,
    Noop
  }

  alias ExPostFacto.{
    DataPoint,
    InputData,
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

  test "backtest/3 returns an initial starting balance of 0.0 if not specified" do
    {:ok, %{result: result}} = ExPostFacto.backtest([], {Noop, :noop, []})

    assert 0.0 == result.starting_balance
  end

  test "backtest/3 allows passing in of an initial starting_balance" do
    {:ok, %{result: result}} =
      ExPostFacto.backtest([], {Noop, :noop, []}, starting_balance: 100.0)

    assert 100.0 == result.starting_balance
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

    expected_data_points = [
      %DataPoint{index: 0, action: :buy, datum: InputData.munge(hd(example_data))}
    ]

    {:ok, %{result: result}} = ExPostFacto.backtest(example_data, mfa)

    assert expected_data_points == result.data_points
  end

  test "backtest/3 handles P&L when there are open positions" do
    example_data = [
      %{high: 1.0, low: 0.0, open: 0.25, close: 0.75}
    ]

    mfa = {BuyBuyBuy, :call, []}

    {:ok, %{result: result}} = ExPostFacto.backtest(example_data, mfa)

    # No realized P&L
    assert 0.0 == result.total_profit_and_loss
  end

  test "backtest/3 collects P&L from the applied strategy when positive" do
    example_data = [
      %{high: 1.0, low: 0.0, open: 0.25, close: 0.75},
      %{high: 100.0, low: 1.0, open: 1.25, close: 1.75}
    ]

    mfa = {BuyBuyBuy, :call, []}

    {:ok, %{result: result}} = ExPostFacto.backtest(example_data, mfa)

    # 1.75 + 0.75 = 2.5
    assert 2.5 == result.total_profit_and_loss
  end

  test "backtest/3 collects P&L from the applied strategy when negative" do
    example_data = [
      %{high: 1.0, low: 0.0, open: 0.25, close: 1.75},
      %{high: 100.0, low: 0.0, open: 1.25, close: 0.75}
    ]

    mfa = {BuyBuyBuy, :call, []}

    {:ok, %{result: result}} = ExPostFacto.backtest(example_data, mfa)

    # 0.75 - 1.75 = -1.0
    assert -1.0 == result.total_profit_and_loss
  end

  test "backtest/3 handles sells for profit" do
    example_data = [
      %{high: 1.0, low: 0.0, open: 0.25, close: 1.75},
      %{high: 100.0, low: 0.0, open: 1.25, close: 0.75}
    ]

    mfa = {SellSellSell, :call, []}

    {:ok, %{result: result}} = ExPostFacto.backtest(example_data, mfa)

    # 1.75 + 0.75 = 2.5
    assert 2.5 == result.total_profit_and_loss
  end

  @tag :focus
  test "backtest/3 handles sells for loss" do
    example_data = [
      %{high: 1.0, low: 0.0, open: 0.25, close: 0.75},
      %{high: 100.0, low: 0.0, open: 1.25, close: 1.75}
    ]

    mfa = {SellSellSell, :call, []}

    {:ok, %{result: result}} = ExPostFacto.backtest(example_data, mfa)

    # 0.75 - 1.75 = -11.0
    assert -1.0 == result.total_profit_and_loss
  end
end
