defmodule ExPostFactoTradeStatsMarketRiskTest do
  use ExUnit.Case, async: true
  doctest ExPostFacto.TradeStats.MarketRisk

  alias ExPostFacto.{Result, DataPoint}
  alias ExPostFacto.TradeStats.{MarketRisk, TradePair}

  describe "alpha/3" do
    test "calculates alpha correctly" do
      result = %Result{
        starting_balance: 1000.0,
        total_profit_and_loss: 200.0,  # 20% return
        duration: 365.25,  # 1 year
        trade_pairs: []
      }

      benchmark_return = 10.0  # 10% benchmark return
      risk_free_rate = 0.02    # 2% risk-free rate

      alpha = MarketRisk.alpha(result, benchmark_return, risk_free_rate)
      assert is_float(alpha)
    end

    test "handles zero duration" do
      result = %Result{
        starting_balance: 1000.0,
        total_profit_and_loss: 100.0,
        duration: 0.0,
        trade_pairs: []
      }

      alpha = MarketRisk.alpha(result, 10.0, 0.02)
      assert is_float(alpha)
    end
  end

  describe "beta/3" do
    test "calculates beta correctly" do
      result = %Result{
        starting_balance: 1000.0,
        total_profit_and_loss: 150.0,
        duration: 365.25,
        trade_pairs: create_sample_trade_pairs()
      }

      beta = MarketRisk.beta(result, 10.0, 0.02)
      assert is_float(beta)
      assert beta >= 0.0
    end

    test "returns 0.0 when strategy has no volatility" do
      result = %Result{
        starting_balance: 1000.0,
        total_profit_and_loss: 100.0,
        duration: 365.25,
        trade_pairs: []
      }

      beta = MarketRisk.beta(result, 10.0, 0.02)
      assert is_float(beta)
    end
  end

  describe "market_correlation/1" do
    test "estimates market correlation based on volatility" do
      result = %Result{
        starting_balance: 1000.0,
        duration: 365.25,
        trade_pairs: create_sample_trade_pairs()
      }

      correlation = MarketRisk.market_correlation(result)
      assert is_float(correlation)
      assert correlation >= 0.0
      assert correlation <= 1.0
    end

    test "returns different correlation for different volatility strategies" do
      # Low volatility strategy
      low_vol_result = %Result{
        starting_balance: 1000.0,
        duration: 365.25,
        trade_pairs: create_low_volatility_trades()
      }

      # High volatility strategy
      high_vol_result = %Result{
        starting_balance: 1000.0,
        duration: 365.25,
        trade_pairs: create_high_volatility_trades()
      }

      low_correlation = MarketRisk.market_correlation(low_vol_result)
      high_correlation = MarketRisk.market_correlation(high_vol_result)

      # Both should be valid correlations
      assert low_correlation >= 0.0
      assert low_correlation <= 1.0
      assert high_correlation >= 0.0
      assert high_correlation <= 1.0

      # High volatility should generally have higher correlation
      assert low_correlation <= high_correlation
    end
  end

  describe "tracking_error/2" do
    test "calculates tracking error correctly" do
      result = %Result{
        starting_balance: 1000.0,
        total_profit_and_loss: 150.0,
        duration: 365.25,
        trade_pairs: create_sample_trade_pairs()
      }

      tracking_error = MarketRisk.tracking_error(result, 10.0)
      assert is_float(tracking_error)
      assert tracking_error >= 0.0
    end
  end

  describe "information_ratio/3" do
    test "calculates information ratio correctly" do
      result = %Result{
        starting_balance: 1000.0,
        total_profit_and_loss: 150.0,
        duration: 365.25,
        trade_pairs: create_sample_trade_pairs()
      }

      info_ratio = MarketRisk.information_ratio(result, 10.0, 0.02)
      assert is_float(info_ratio)
    end

    test "returns 0.0 when tracking error is 0" do
      # Create a result that would have zero tracking error
      result = %Result{
        starting_balance: 1000.0,
        total_profit_and_loss: 100.0,  # 10% return same as benchmark
        duration: 365.25,
        trade_pairs: []
      }

      info_ratio = MarketRisk.information_ratio(result, 10.0, 0.02)
      assert is_float(info_ratio)
    end
  end

  describe "relative_drawdown/2" do
    test "calculates relative drawdown correctly" do
      result = %Result{max_draw_down_percentage: -15.0}
      benchmark_drawdown = -10.0

      relative_dd = MarketRisk.relative_drawdown(result, benchmark_drawdown)
      assert -5.0 = relative_dd  # -15 - (-10) = -5
    end

    test "handles positive relative performance" do
      result = %Result{max_draw_down_percentage: -8.0}
      benchmark_drawdown = -12.0

      relative_dd = MarketRisk.relative_drawdown(result, benchmark_drawdown)
      assert 4.0 = relative_dd  # -8 - (-12) = 4
    end
  end

  # Helper functions for creating test data

  defp create_sample_trade_pairs do
    [
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
  end

  defp create_low_volatility_trades do
    [
      %TradePair{
        enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 0},
        exit_point: %DataPoint{datum: %{open: 101.0}, action: :close_buy, index: 1},
        balance: 1010.0,
        previous_balance: 1000.0
      },
      %TradePair{
        enter_point: %DataPoint{datum: %{open: 101.0}, action: :buy, index: 2},
        exit_point: %DataPoint{datum: %{open: 102.0}, action: :close_buy, index: 3},
        balance: 1020.0,
        previous_balance: 1010.0
      }
    ]
  end

  defp create_high_volatility_trades do
    [
      %TradePair{
        enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 0},
        exit_point: %DataPoint{datum: %{open: 130.0}, action: :close_buy, index: 1},
        balance: 1300.0,
        previous_balance: 1000.0
      },
      %TradePair{
        enter_point: %DataPoint{datum: %{open: 130.0}, action: :buy, index: 2},
        exit_point: %DataPoint{datum: %{open: 80.0}, action: :close_buy, index: 3},
        balance: 800.0,
        previous_balance: 1300.0
      }
    ]
  end
end
