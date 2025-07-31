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
end
