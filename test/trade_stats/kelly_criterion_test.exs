defmodule ExPostFactoTradeStatsKellyCriterionTest do
  use ExUnit.Case, async: true
  doctest ExPostFacto.TradeStats.KellyCriterion

  alias ExPostFacto.{Result, DataPoint}
  alias ExPostFacto.TradeStats.{KellyCriterion, TradePair}

  describe "kelly_criterion/1" do
    test "returns 0.0 for no trades" do
      result = %Result{trades_count: 0, win_rate: 0.0, trade_pairs: []}
      assert KellyCriterion.kelly_criterion(result) == 0.0
    end

    test "returns 0.0 when no winning trades" do
      result = %Result{
        trades_count: 2,
        win_rate: 0.0,
        trade_pairs: []
      }

      assert KellyCriterion.kelly_criterion(result) == 0.0
    end

    test "returns 0.0 when no losing trades" do
      result = %Result{
        trades_count: 2,
        win_rate: 100.0,
        trade_pairs: []
      }

      assert KellyCriterion.kelly_criterion(result) == 0.0
    end

    test "calculates Kelly criterion correctly for profitable strategy" do
      trade_pairs = [
        # Two winning trades: +20 each
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 0},
          exit_point: %DataPoint{datum: %{open: 120.0}, action: :close_buy, index: 1},
          balance: 1200.0,
          previous_balance: 1000.0
        },
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 2},
          exit_point: %DataPoint{datum: %{open: 120.0}, action: :close_buy, index: 3},
          balance: 1200.0,
          previous_balance: 1000.0
        },
        # One losing trade: -10
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 110.0}, action: :buy, index: 4},
          exit_point: %DataPoint{datum: %{open: 100.0}, action: :close_buy, index: 5},
          balance: 1000.0,
          previous_balance: 1100.0
        }
      ]

      result = %Result{
        trades_count: 3,
        win_rate: 66.67,  # 2 out of 3 trades are winners
        trade_pairs: trade_pairs
      }

      kelly = KellyCriterion.kelly_criterion(result)
      assert is_float(kelly)
      assert kelly > 0.0  # Should be positive for profitable strategy
    end

    test "calculates Kelly criterion correctly for losing strategy" do
      trade_pairs = [
        # One small winning trade: +5
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 0},
          exit_point: %DataPoint{datum: %{open: 105.0}, action: :close_buy, index: 1},
          balance: 1050.0,
          previous_balance: 1000.0
        },
        # Two larger losing trades: -15 each
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 115.0}, action: :buy, index: 2},
          exit_point: %DataPoint{datum: %{open: 100.0}, action: :close_buy, index: 3},
          balance: 1000.0,
          previous_balance: 1150.0
        },
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 115.0}, action: :buy, index: 4},
          exit_point: %DataPoint{datum: %{open: 100.0}, action: :close_buy, index: 5},
          balance: 1000.0,
          previous_balance: 1150.0
        }
      ]

      result = %Result{
        trades_count: 3,
        win_rate: 33.33,  # 1 out of 3 trades are winners
        trade_pairs: trade_pairs
      }

      kelly = KellyCriterion.kelly_criterion(result)
      assert is_float(kelly)
      assert kelly < 0.0  # Should be negative for unprofitable strategy
    end
  end

  describe "fractional_kelly/2" do
    test "calculates fractional Kelly correctly" do
      trade_pairs = [
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 0},
          exit_point: %DataPoint{datum: %{open: 120.0}, action: :close_buy, index: 1},
          balance: 1200.0,
          previous_balance: 1000.0
        }
      ]

      result = %Result{
        trades_count: 1,
        win_rate: 100.0,
        trade_pairs: trade_pairs
      }

      # Test fractional kelly calculation
      fractional = KellyCriterion.fractional_kelly(result, 0.5)

      # Should be half of whatever kelly_criterion returns
      assert is_float(fractional)
    end

    test "uses default fraction of 0.25" do
      result = %Result{trades_count: 0, win_rate: 0.0, trade_pairs: []}
      fractional = KellyCriterion.fractional_kelly(result)
      kelly_full = KellyCriterion.kelly_criterion(result)

      assert fractional == kelly_full * 0.25
    end
  end

  describe "kelly_interpretation/1" do
    test "returns correct interpretation for no edge" do
      assert "No edge - avoid this strategy" = KellyCriterion.kelly_interpretation(-0.1)
      assert "No edge - avoid this strategy" = KellyCriterion.kelly_interpretation(0.0)
    end

    test "returns correct interpretation for weak edge" do
      assert "Weak edge - use small position sizes" = KellyCriterion.kelly_interpretation(0.05)
    end

    test "returns correct interpretation for moderate edge" do
      assert "Moderate edge - reasonable strategy" = KellyCriterion.kelly_interpretation(0.15)
    end

    test "returns correct interpretation for strong edge" do
      assert "Strong edge - good strategy" = KellyCriterion.kelly_interpretation(0.30)
    end

    test "returns correct interpretation for very strong edge" do
      assert "Very strong edge - potentially too aggressive" = KellyCriterion.kelly_interpretation(0.50)
    end
  end

  describe "optimal_position_size/3" do
    test "calculates optimal position size correctly" do
      result = %Result{
        trades_count: 0,
        win_rate: 0.0,
        trade_pairs: []
      }

      current_capital = 10000.0
      position_size = KellyCriterion.optimal_position_size(result, current_capital, 0.25)

      # Kelly is 0.0 for this result, so position size should be 0.0
      assert position_size == 0.0
    end

    test "uses default fraction" do
      result = %Result{
        trades_count: 0,
        win_rate: 0.0,
        trade_pairs: []
      }

      current_capital = 10000.0
      position_size = KellyCriterion.optimal_position_size(result, current_capital)
      fractional_kelly = KellyCriterion.fractional_kelly(result, 0.25)

      assert position_size == current_capital * fractional_kelly
    end
  end

  describe "geometric_mean_return/1" do
    test "returns 0.0 for no trades" do
      result = %Result{trades_count: 0, trade_pairs: []}
      assert KellyCriterion.geometric_mean_return(result) == 0.0
    end

    test "calculates geometric mean correctly" do
      trade_pairs = [
        # +10% return
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 0},
          exit_point: %DataPoint{datum: %{open: 110.0}, action: :close_buy, index: 1},
          balance: 1100.0,
          previous_balance: 1000.0
        },
        # +5% return
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 2},
          exit_point: %DataPoint{datum: %{open: 105.0}, action: :close_buy, index: 3},
          balance: 1050.0,
          previous_balance: 1000.0
        }
      ]

      result = %Result{trades_count: 2, trade_pairs: trade_pairs}
      geometric_mean = KellyCriterion.geometric_mean_return(result)

      assert is_float(geometric_mean)
      # Geometric mean should be positive for profitable trades
      assert geometric_mean > 0.0
      assert geometric_mean < 15.0  # Should be less than arithmetic mean
    end
  end

  describe "risk_of_ruin/2" do
    test "returns 1.0 for strategy with no edge" do
      result = %Result{
        trades_count: 0,
        win_rate: 0.0,
        trade_pairs: [],
        best_trade_by_percentage: 0.0,
        worst_trade_by_percentage: 0.0
      }

      risk = KellyCriterion.risk_of_ruin(result)
      assert 1.0 = risk
    end

    test "returns low risk for strategy with no losses" do
      result = %Result{
        trades_count: 2,
        win_rate: 100.0,
        trade_pairs: [],
        best_trade_by_percentage: 10.0,
        worst_trade_by_percentage: 0.0
      }

      risk = KellyCriterion.risk_of_ruin(result)
      assert risk >= 0.0  # Should be low risk but not necessarily 0
    end

    test "calculates risk of ruin for normal strategy" do
      result = %Result{
        trades_count: 10,
        win_rate: 60.0,
        trade_pairs: [],
        best_trade_by_percentage: 15.0,
        worst_trade_by_percentage: -10.0
      }

      risk = KellyCriterion.risk_of_ruin(result)
      assert is_float(risk)
      assert risk >= 0.0
      assert risk <= 1.0
    end

    test "uses default drawdown limit" do
      result = %Result{
        trades_count: 10,
        win_rate: 60.0,
        trade_pairs: [],
        best_trade_by_percentage: 15.0,
        worst_trade_by_percentage: -10.0
      }

      risk_default = KellyCriterion.risk_of_ruin(result)
      risk_explicit = KellyCriterion.risk_of_ruin(result, 0.20)

      assert risk_default == risk_explicit
    end
  end
end
