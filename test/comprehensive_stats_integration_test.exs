defmodule ExPostFactoComprehensiveStatsIntegrationTest do
  use ExUnit.Case, async: true

  alias ExPostFacto.Result

  describe "comprehensive statistics integration" do
    test "compiles all statistics correctly for a complete backtest result" do
      # Create sample market data
      market_data = [
        %{
          high: 105.0,
          low: 95.0,
          open: 100.0,
          close: 102.0,
          volume: 1000.0,
          timestamp: "2023-01-01"
        },
        %{
          high: 108.0,
          low: 98.0,
          open: 102.0,
          close: 106.0,
          volume: 1200.0,
          timestamp: "2023-01-02"
        },
        %{
          high: 110.0,
          low: 100.0,
          open: 106.0,
          close: 104.0,
          volume: 1100.0,
          timestamp: "2023-01-03"
        },
        %{
          high: 115.0,
          low: 105.0,
          open: 104.0,
          close: 112.0,
          volume: 1300.0,
          timestamp: "2023-01-04"
        },
        %{
          high: 118.0,
          low: 108.0,
          open: 112.0,
          close: 110.0,
          volume: 1000.0,
          timestamp: "2023-01-05"
        },
        %{
          high: 116.0,
          low: 106.0,
          open: 110.0,
          close: 108.0,
          volume: 900.0,
          timestamp: "2023-01-06"
        },
        %{
          high: 112.0,
          low: 102.0,
          open: 108.0,
          close: 105.0,
          volume: 1100.0,
          timestamp: "2023-01-07"
        },
        %{
          high: 109.0,
          low: 99.0,
          open: 105.0,
          close: 107.0,
          volume: 1000.0,
          timestamp: "2023-01-08"
        }
      ]

      # Run a simple buy-and-hold-like backtest
      {:ok, output} =
        ExPostFacto.backtest(
          market_data,
          {__MODULE__, :simple_strategy, []},
          starting_balance: 10000.0
        )

      result = output.result

      # Verify all comprehensive statistics are calculated
      assert is_float(result.total_return_pct)
      assert is_float(result.cagr_pct)
      assert is_float(result.sharpe_ratio)
      assert is_float(result.sortino_ratio)
      assert is_float(result.calmar_ratio)
      assert is_float(result.profit_factor) || result.profit_factor == :infinity
      assert is_float(result.expectancy)
      assert is_float(result.expectancy_pct)
      assert is_float(result.sqn)
      assert is_binary(result.sqn_interpretation)
      assert is_float(result.kelly_criterion)
      assert is_binary(result.kelly_interpretation)
      assert is_float(result.annual_volatility)
      assert is_float(result.alpha)
      assert is_float(result.beta)
      assert is_float(result.information_ratio)
      assert is_float(result.tracking_error)
      assert is_float(result.market_correlation)
      assert is_float(result.gross_profit)
      assert is_float(result.gross_loss)
      assert is_float(result.average_winning_trade)
      assert is_float(result.average_losing_trade)
      assert is_float(result.largest_winning_trade)
      assert is_float(result.largest_losing_trade)
    end

    test "comprehensive_summary/1 returns clean summary without internal data" do
      # Create a simple result with some trades
      market_data = [
        %{
          high: 105.0,
          low: 95.0,
          open: 100.0,
          close: 102.0,
          volume: 1000.0,
          timestamp: "2023-01-01"
        },
        %{
          high: 108.0,
          low: 98.0,
          open: 102.0,
          close: 106.0,
          volume: 1200.0,
          timestamp: "2023-01-02"
        },
        %{
          high: 110.0,
          low: 100.0,
          open: 106.0,
          close: 104.0,
          volume: 1100.0,
          timestamp: "2023-01-03"
        }
      ]

      {:ok, output} =
        ExPostFacto.backtest(
          market_data,
          {__MODULE__, :simple_strategy, []},
          starting_balance: 10000.0
        )

      summary = Result.comprehensive_summary(output.result)

      # Check that it's a clean map without internal structures
      refute Map.has_key?(summary, :data_points)
      refute Map.has_key?(summary, :trade_pairs)
      refute Map.has_key?(summary, :is_position_open)

      # Check that it has all the key metrics
      assert Map.has_key?(summary, :starting_balance)
      assert Map.has_key?(summary, :final_balance)
      assert Map.has_key?(summary, :total_return_pct)
      assert Map.has_key?(summary, :cagr_pct)
      assert Map.has_key?(summary, :sharpe_ratio)
      assert Map.has_key?(summary, :sortino_ratio)
      assert Map.has_key?(summary, :calmar_ratio)
      assert Map.has_key?(summary, :profit_factor)
      assert Map.has_key?(summary, :expectancy)
      assert Map.has_key?(summary, :sqn)
      assert Map.has_key?(summary, :kelly_criterion)
      assert Map.has_key?(summary, :alpha)
      assert Map.has_key?(summary, :beta)

      # Verify calculated values make sense
      assert summary.starting_balance == 10000.0
      assert summary.final_balance >= summary.starting_balance
      assert is_binary(summary.sqn_interpretation)
      assert is_binary(summary.kelly_interpretation)
    end

    test "handles edge cases gracefully" do
      # Test with minimal data that might cause division by zero or other edge cases
      market_data = [
        %{
          high: 100.0,
          low: 100.0,
          open: 100.0,
          close: 100.0,
          volume: 1000.0,
          timestamp: "2023-01-01"
        }
      ]

      {:ok, output} =
        ExPostFacto.backtest(
          market_data,
          {__MODULE__, :no_action_strategy, []},
          starting_balance: 10000.0
        )

      result = output.result

      # Should not crash and should have reasonable defaults
      assert result.total_return_pct == 0.0
      assert result.cagr_pct == 0.0
      assert result.sharpe_ratio == 0.0
      assert result.trades_count == 0
      assert result.win_rate == 0.0
      assert result.profit_factor == 0.0
      assert result.sqn == 0.0
      assert result.kelly_criterion == 0.0
    end

    test "statistics are consistent with traditional calculations" do
      # Create a known scenario and verify the statistics make sense
      market_data = [
        %{
          high: 105.0,
          low: 95.0,
          open: 100.0,
          close: 102.0,
          volume: 1000.0,
          timestamp: "2023-01-01"
        },
        # Buy signal
        %{
          high: 108.0,
          low: 98.0,
          open: 102.0,
          close: 110.0,
          volume: 1200.0,
          timestamp: "2023-01-02"
        },
        %{
          high: 115.0,
          low: 105.0,
          open: 110.0,
          close: 112.0,
          volume: 1100.0,
          timestamp: "2023-01-03"
        },
        # Sell signal
        %{
          high: 118.0,
          low: 108.0,
          open: 112.0,
          close: 115.0,
          volume: 1300.0,
          timestamp: "2023-01-04"
        },
        %{
          high: 120.0,
          low: 110.0,
          open: 115.0,
          close: 118.0,
          volume: 1000.0,
          timestamp: "2023-01-05"
        }
      ]

      {:ok, output} =
        ExPostFacto.backtest(
          market_data,
          {__MODULE__, :buy_high_sell_higher_strategy, []},
          starting_balance: 10000.0
        )

      result = output.result

      # Should have made at least one trade
      assert result.trades_count > 0

      # If trades were made, check profitability
      if result.trades_count > 0 do
        # May be zero if break-even
        assert result.total_profit_and_loss >= 0.0
        assert result.total_return_pct >= 0.0
        assert result.win_rate >= 0.0
        assert result.profit_factor >= 0.0 || result.profit_factor == :infinity
      end

      # SQN should be reasonable
      assert is_float(result.sqn)
      assert is_binary(result.sqn_interpretation)

      # Kelly should be calculable
      assert is_float(result.kelly_criterion)
      assert is_binary(result.kelly_interpretation)
    end
  end

  # Simple test strategies

  def simple_strategy(%{close: _close}, %{data_points: data_points}) do
    case length(data_points) do
      # Buy on first data point
      0 -> :buy
      # Sell on second data point
      1 -> :close_buy
      _ -> :noop
    end
  end

  def no_action_strategy(_market_data, _result) do
    :noop
  end

  def buy_high_sell_higher_strategy(%{close: close}, %{
        data_points: _data_points,
        is_position_open: is_open
      }) do
    cond do
      # Buy when price is high
      !is_open && close > 108.0 -> :buy
      # Sell when price is even higher
      is_open && close > 114.0 -> :close_buy
      true -> :noop
    end
  end
end
