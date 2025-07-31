defmodule ExPostFactoTradeStatsFinancialRatiosTest do
  use ExUnit.Case, async: true
  doctest ExPostFacto.TradeStats.FinancialRatios

  alias ExPostFacto.{Result, DataPoint}
  alias ExPostFacto.TradeStats.{FinancialRatios, TradePair}

  describe "sharpe_ratio/2" do
    test "returns 0.0 when volatility is 0" do
      result = %Result{
        starting_balance: 1000.0,
        total_profit_and_loss: 100.0,
        duration: 365.0,
        trade_pairs: []
      }

      assert FinancialRatios.sharpe_ratio(result) == 0.0
    end

    test "calculates sharpe ratio correctly" do
      # Create a result with some profitable and losing trades
      trade_pairs = [
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 0},
          exit_point: %DataPoint{datum: %{open: 110.0}, action: :close_buy, index: 1},
          balance: 1100.0,
          previous_balance: 1000.0
        },
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 110.0}, action: :buy, index: 2},
          exit_point: %DataPoint{datum: %{open: 105.0}, action: :close_buy, index: 3},
          balance: 1050.0,
          previous_balance: 1100.0
        }
      ]

      result = %Result{
        starting_balance: 1000.0,
        total_profit_and_loss: 50.0,
        duration: 365.0,
        trade_pairs: trade_pairs
      }

      sharpe = FinancialRatios.sharpe_ratio(result)
      assert is_float(sharpe)
    end
  end

  describe "sortino_ratio/2" do
    test "returns 0.0 when downside volatility is 0" do
      # All profitable trades
      trade_pairs = [
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 0},
          exit_point: %DataPoint{datum: %{open: 110.0}, action: :close_buy, index: 1},
          balance: 1100.0,
          previous_balance: 1000.0
        }
      ]

      result = %Result{
        starting_balance: 1000.0,
        total_profit_and_loss: 100.0,
        duration: 365.0,
        trade_pairs: trade_pairs
      }

      sortino = FinancialRatios.sortino_ratio(result)
      assert is_float(sortino)
    end
  end

  describe "calmar_ratio/1" do
    test "returns 0.0 when max drawdown is 0" do
      result = %Result{
        starting_balance: 1000.0,
        total_profit_and_loss: 100.0,
        duration: 365.0,
        max_draw_down_percentage: 0.0,
        trade_pairs: []
      }

      assert FinancialRatios.calmar_ratio(result) == 0.0
    end

    test "calculates calmar ratio correctly" do
      result = %Result{
        starting_balance: 1000.0,
        total_profit_and_loss: 100.0,
        duration: 365.0,
        max_draw_down_percentage: -10.0,
        trade_pairs: []
      }

      calmar = FinancialRatios.calmar_ratio(result)
      assert is_float(calmar)
      assert calmar > 0.0
    end
  end

  describe "annual_return_percentage/1" do
    test "returns 0.0 when starting balance is 0" do
      result = %Result{starting_balance: 0.0, duration: 365.0}
      assert FinancialRatios.annual_return_percentage(result) == 0.0
    end

    test "returns 0.0 when duration is nil" do
      result = %Result{starting_balance: 1000.0, duration: nil}
      assert FinancialRatios.annual_return_percentage(result) == 0.0
    end

    test "returns 0.0 when duration is 0" do
      result = %Result{starting_balance: 1000.0, duration: 0.0}
      assert FinancialRatios.annual_return_percentage(result) == 0.0
    end

    test "calculates annual return correctly for one year" do
      result = %Result{
        starting_balance: 1000.0,
        total_profit_and_loss: 100.0,
        duration: 365.25
      }

      annual_return = FinancialRatios.annual_return_percentage(result)
      assert_in_delta annual_return, 10.0, 0.1
    end

    test "calculates annual return correctly for multiple years" do
      result = %Result{
        starting_balance: 1000.0,
        total_profit_and_loss: 210.0,  # 21% total return
        duration: 730.5  # 2 years
      }

      annual_return = FinancialRatios.annual_return_percentage(result)
      # Should be approximately 10% annually compounded
      assert annual_return > 9.0
      assert annual_return < 11.0
    end
  end

  describe "total_return_percentage/1" do
    test "returns 0.0 when starting balance is 0" do
      result = %Result{starting_balance: 0.0, total_profit_and_loss: 100.0}
      assert FinancialRatios.total_return_percentage(result) == 0.0
    end

    test "calculates total return correctly" do
      result = %Result{
        starting_balance: 1000.0,
        total_profit_and_loss: 250.0
      }

      total_return = FinancialRatios.total_return_percentage(result)
      assert 25.0 = total_return
    end

    test "handles negative returns" do
      result = %Result{
        starting_balance: 1000.0,
        total_profit_and_loss: -100.0
      }

      total_return = FinancialRatios.total_return_percentage(result)
      assert -10.0 = total_return
    end
  end

  describe "annual_volatility/1" do
    test "returns 0.0 for empty trade pairs" do
      result = %Result{trade_pairs: [], duration: 365.0}
      assert FinancialRatios.annual_volatility(result) == 0.0
    end

    test "returns 0.0 for single trade" do
      trade_pairs = [
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 0},
          exit_point: %DataPoint{datum: %{open: 110.0}, action: :close_buy, index: 1},
          balance: 1100.0,
          previous_balance: 1000.0
        }
      ]

      result = %Result{trade_pairs: trade_pairs, duration: 365.0}
      assert FinancialRatios.annual_volatility(result) == 0.0
    end

    test "calculates volatility for multiple trades" do
      trade_pairs = [
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 0},
          exit_point: %DataPoint{datum: %{open: 110.0}, action: :close_buy, index: 1},
          balance: 1100.0,
          previous_balance: 1000.0
        },
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 110.0}, action: :buy, index: 2},
          exit_point: %DataPoint{datum: %{open: 100.0}, action: :close_buy, index: 3},
          balance: 1000.0,
          previous_balance: 1100.0
        }
      ]

      result = %Result{trade_pairs: trade_pairs, duration: 365.0}
      volatility = FinancialRatios.annual_volatility(result)
      assert is_float(volatility)
      assert volatility > 0.0
    end
  end
end
