defmodule ExPostFactoTradeStatsSystemQualityTest do
  use ExUnit.Case, async: true
  doctest ExPostFacto.TradeStats.SystemQuality

  alias ExPostFacto.{Result, DataPoint}
  alias ExPostFacto.TradeStats.{SystemQuality, TradePair}

  describe "system_quality_number/1" do
    test "returns 0.0 for no trades" do
      result = %Result{trades_count: 0, trade_pairs: []}
      assert SystemQuality.system_quality_number(result) == 0.0
    end

    test "returns 0.0 for single trade" do
      result = %Result{trades_count: 1, trade_pairs: []}
      assert SystemQuality.system_quality_number(result) == 0.0
    end

    test "returns 0.0 when standard deviation is 0" do
      # All trades have same result
      trade_pairs = [
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 0},
          exit_point: %DataPoint{datum: %{open: 110.0}, action: :close_buy, index: 1},
          balance: 1100.0,
          previous_balance: 1000.0
        },
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 2},
          exit_point: %DataPoint{datum: %{open: 110.0}, action: :close_buy, index: 3},
          balance: 1100.0,
          previous_balance: 1000.0
        }
      ]

      result = %Result{trades_count: 2, trade_pairs: trade_pairs}
      assert SystemQuality.system_quality_number(result) == 0.0
    end

    test "calculates SQN correctly for mixed results" do
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
        },
        # Winning trade: +15
        %TradePair{
          enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: 4},
          exit_point: %DataPoint{datum: %{open: 115.0}, action: :close_buy, index: 5},
          balance: 1150.0,
          previous_balance: 1000.0
        }
      ]

      result = %Result{trades_count: 3, trade_pairs: trade_pairs}
      sqn = SystemQuality.system_quality_number(result)

      assert is_float(sqn)
      # Should be positive since average is positive
      assert sqn > 0.0
    end
  end

  describe "sqn_interpretation/1" do
    test "returns correct interpretation for poor system" do
      assert "Poor system" = SystemQuality.sqn_interpretation(1.0)
    end

    test "returns correct interpretation for below average system" do
      assert "Below average but tradeable" = SystemQuality.sqn_interpretation(1.7)
    end

    test "returns correct interpretation for average system" do
      assert "Average system" = SystemQuality.sqn_interpretation(2.2)
    end

    test "returns correct interpretation for good system" do
      assert "Good system" = SystemQuality.sqn_interpretation(2.7)
    end

    test "returns correct interpretation for excellent system" do
      assert "Excellent system" = SystemQuality.sqn_interpretation(4.0)
    end

    test "returns correct interpretation for superb system" do
      assert "Superb system" = SystemQuality.sqn_interpretation(6.0)
    end

    test "returns correct interpretation for too good to be true" do
      assert "Too good to be true (likely curve-fitted)" = SystemQuality.sqn_interpretation(8.0)
    end
  end

  describe "confidence_level/1" do
    test "returns 0.0 for insufficient trades" do
      result = %Result{trades_count: 20}
      assert SystemQuality.confidence_level(result) == 0.0
    end

    test "returns confidence level for adequate trades" do
      # Mock a result that would give a good SQN
      trade_pairs =
        Enum.map(1..50, fn i ->
          # Create alternating winning and slightly smaller losing trades
          if rem(i, 2) == 0 do
            %TradePair{
              enter_point: %DataPoint{datum: %{open: 100.0}, action: :buy, index: i * 2},
              exit_point: %DataPoint{datum: %{open: 110.0}, action: :close_buy, index: i * 2 + 1},
              balance: 1100.0,
              previous_balance: 1000.0
            }
          else
            %TradePair{
              enter_point: %DataPoint{datum: %{open: 105.0}, action: :buy, index: i * 2},
              exit_point: %DataPoint{datum: %{open: 100.0}, action: :close_buy, index: i * 2 + 1},
              balance: 1000.0,
              previous_balance: 1050.0
            }
          end
        end)

      result = %Result{trades_count: 50, trade_pairs: trade_pairs}
      confidence = SystemQuality.confidence_level(result)

      assert is_float(confidence)
      assert confidence >= 0.0
      assert confidence <= 1.0
    end
  end
end
