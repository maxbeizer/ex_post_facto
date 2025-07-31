defmodule ExPostFactoTradeStatsProfitMetricsTest do
  use ExUnit.Case, async: true
  doctest ExPostFacto.TradeStats.ProfitMetrics

  alias ExPostFacto.{Result, DataPoint}
  alias ExPostFacto.TradeStats.{ProfitMetrics, TradePair}

  describe "profit_factor/1" do
    test "returns 0.0 when no trades" do
      result = %Result{trade_pairs: []}
      assert ProfitMetrics.profit_factor(result) == 0.0
    end

    test "returns infinity when no losses" do
      trade_pairs = [
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 0},
          exit_point: %DataPoint{datum: %{open: 110.0}, action: :close_buy, index: 1},
          balance: 1100.0,
          previous_balance: 1000.0
        }
      ]

      result = %Result{trade_pairs: trade_pairs}
      assert :infinity = ProfitMetrics.profit_factor(result)
    end

    test "calculates profit factor correctly" do
      trade_pairs = [
        # Winning trade: +10
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 0},
          exit_point: %DataPoint{datum: %{open: 110.0}, action: :close_buy, index: 1},
          balance: 1100.0,
          previous_balance: 1000.0
        },
        # Losing trade: -5
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 110.0}, action: :buy, index: 2},
          exit_point: %DataPoint{datum: %{open: 105.0}, action: :close_buy, index: 3},
          balance: 1050.0,
          previous_balance: 1100.0
        }
      ]

      result = %Result{trade_pairs: trade_pairs}
      profit_factor = ProfitMetrics.profit_factor(result)

      # Gross profit = 10, Gross loss = 5, Profit factor = 10/5 = 2.0
      assert 2.0 = profit_factor
    end
  end

  describe "expectancy/1" do
    test "returns 0.0 when no trades" do
      result = %Result{trades_count: 0, total_profit_and_loss: 0.0}
      assert ProfitMetrics.expectancy(result) == 0.0
    end

    test "calculates expectancy correctly" do
      result = %Result{
        trades_count: 5,
        total_profit_and_loss: 100.0
      }

      expectancy = ProfitMetrics.expectancy(result)
      assert 20.0 = expectancy
    end
  end

  describe "expectancy_percentage/1" do
    test "returns 0.0 when starting balance is 0" do
      result = %Result{
        starting_balance: 0.0,
        trades_count: 5,
        total_profit_and_loss: 100.0
      }

      assert ProfitMetrics.expectancy_percentage(result) == 0.0
    end

    test "calculates expectancy percentage correctly" do
      result = %Result{
        starting_balance: 1000.0,
        trades_count: 5,
        total_profit_and_loss: 100.0
      }

      expectancy_pct = ProfitMetrics.expectancy_percentage(result)
      # 20/1000 * 100 = 2%
      assert 2.0 = expectancy_pct
    end
  end

  describe "gross_profit_and_loss/1" do
    test "returns {0.0, 0.0} for empty trade pairs" do
      result = %Result{trade_pairs: []}
      assert ProfitMetrics.gross_profit_and_loss(result) == {0.0, 0.0}
    end

    test "calculates gross profit and loss correctly" do
      trade_pairs = [
        # Winning trade: +10
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 0},
          exit_point: %DataPoint{datum: %{open: 110.0}, action: :close_buy, index: 1},
          balance: 1100.0,
          previous_balance: 1000.0
        },
        # Another winning trade: +5
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 2},
          exit_point: %DataPoint{datum: %{open: 105.0}, action: :close_buy, index: 3},
          balance: 1050.0,
          previous_balance: 1000.0
        },
        # Losing trade: -8
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 110.0}, action: :buy, index: 4},
          exit_point: %DataPoint{datum: %{open: 102.0}, action: :close_buy, index: 5},
          balance: 1020.0,
          previous_balance: 1100.0
        }
      ]

      result = %Result{trade_pairs: trade_pairs}
      {gross_profit, gross_loss} = ProfitMetrics.gross_profit_and_loss(result)

      # 10 + 5
      assert 15.0 = gross_profit
      # -8
      assert -8.0 = gross_loss
    end
  end

  describe "average_winning_trade/1" do
    test "returns 0.0 for no winning trades" do
      trade_pairs = [
        # Losing trade
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 110.0}, action: :buy, index: 0},
          exit_point: %DataPoint{datum: %{open: 100.0}, action: :close_buy, index: 1},
          balance: 1000.0,
          previous_balance: 1100.0
        }
      ]

      result = %Result{trade_pairs: trade_pairs}
      assert ProfitMetrics.average_winning_trade(result) == 0.0
    end

    test "calculates average winning trade correctly" do
      trade_pairs = [
        # Winning trade: +10
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 0},
          exit_point: %DataPoint{datum: %{open: 110.0}, action: :close_buy, index: 1},
          balance: 1100.0,
          previous_balance: 1000.0
        },
        # Winning trade: +20
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 2},
          exit_point: %DataPoint{datum: %{open: 120.0}, action: :close_buy, index: 3},
          balance: 1200.0,
          previous_balance: 1000.0
        }
      ]

      result = %Result{trade_pairs: trade_pairs}
      average_win = ProfitMetrics.average_winning_trade(result)
      # (10 + 20) / 2
      assert 15.0 = average_win
    end
  end

  describe "average_losing_trade/1" do
    test "returns 0.0 for no losing trades" do
      trade_pairs = [
        # Winning trade
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 0},
          exit_point: %DataPoint{datum: %{open: 110.0}, action: :close_buy, index: 1},
          balance: 1100.0,
          previous_balance: 1000.0
        }
      ]

      result = %Result{trade_pairs: trade_pairs}
      assert ProfitMetrics.average_losing_trade(result) == 0.0
    end

    test "calculates average losing trade correctly" do
      trade_pairs = [
        # Losing trade: -10
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 110.0}, action: :buy, index: 0},
          exit_point: %DataPoint{datum: %{open: 100.0}, action: :close_buy, index: 1},
          balance: 1000.0,
          previous_balance: 1100.0
        },
        # Losing trade: -5
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 105.0}, action: :buy, index: 2},
          exit_point: %DataPoint{datum: %{open: 100.0}, action: :close_buy, index: 3},
          balance: 1000.0,
          previous_balance: 1050.0
        }
      ]

      result = %Result{trade_pairs: trade_pairs}
      average_loss = ProfitMetrics.average_losing_trade(result)
      # (-10 + -5) / 2
      assert -7.5 = average_loss
    end
  end

  describe "largest_winning_trade/1" do
    test "returns 0.0 for no winning trades" do
      result = %Result{trade_pairs: []}
      assert ProfitMetrics.largest_winning_trade(result) == 0.0
    end

    test "finds largest winning trade correctly" do
      trade_pairs = [
        # Winning trade: +10
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 0},
          exit_point: %DataPoint{datum: %{open: 110.0}, action: :close_buy, index: 1},
          balance: 1100.0,
          previous_balance: 1000.0
        },
        # Larger winning trade: +25
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 2},
          exit_point: %DataPoint{datum: %{open: 125.0}, action: :close_buy, index: 3},
          balance: 1250.0,
          previous_balance: 1000.0
        }
      ]

      result = %Result{trade_pairs: trade_pairs}
      largest_win = ProfitMetrics.largest_winning_trade(result)
      assert 25.0 = largest_win
    end
  end

  describe "largest_losing_trade/1" do
    test "returns 0.0 for no losing trades" do
      result = %Result{trade_pairs: []}
      assert ProfitMetrics.largest_losing_trade(result) == 0.0
    end

    test "finds largest losing trade correctly" do
      trade_pairs = [
        # Losing trade: -5
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 105.0}, action: :buy, index: 0},
          exit_point: %DataPoint{datum: %{open: 100.0}, action: :close_buy, index: 1},
          balance: 1000.0,
          previous_balance: 1050.0
        },
        # Larger losing trade: -15
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 115.0}, action: :buy, index: 2},
          exit_point: %DataPoint{datum: %{open: 100.0}, action: :close_buy, index: 3},
          balance: 1000.0,
          previous_balance: 1150.0
        }
      ]

      result = %Result{trade_pairs: trade_pairs}
      largest_loss = ProfitMetrics.largest_losing_trade(result)
      assert -15.0 = largest_loss
    end
  end
end
