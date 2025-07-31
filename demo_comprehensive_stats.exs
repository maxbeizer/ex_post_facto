#!/usr/bin/env elixir

# Demo script to showcase comprehensive trading statistics
defmodule ComprehensiveStatsDemo do
  @moduledoc """
  Demonstrates the comprehensive statistics available in ExPostFacto.

  This script runs a simple moving average crossover strategy and shows
  all the new professional-grade metrics that are now calculated.
  """

  # Simple moving average crossover strategy for demonstration
  def sma_crossover_strategy(%{close: close}, %{data_points: data_points, is_position_open: is_position_open}) do
    # Calculate simple moving averages (simplified for demo)
    prices = [close | Enum.map(data_points, fn dp -> dp.datum.close end)]

    case length(prices) do
      len when len < 20 -> :noop  # Not enough data
      _ ->
        sma_10 = (prices |> Enum.take(10) |> Enum.sum()) / 10
        sma_20 = (prices |> Enum.take(20) |> Enum.sum()) / 20

        cond do
          !is_position_open && sma_10 > sma_20 -> :buy
          is_position_open && sma_10 < sma_20 -> :close_buy
          true -> :noop
        end
    end
  end

  def run_demo do
    IO.puts("\n🚀 ExPostFacto Comprehensive Statistics Demo")
    IO.puts("=" |> String.duplicate(50))

    # Generate sample market data (simplified price movements)
    market_data = generate_sample_data()

    IO.puts("\n📊 Running backtest with SMA crossover strategy...")

    # Run the backtest
    {:ok, output} = ExPostFacto.backtest(
      market_data,
      {__MODULE__, :sma_crossover_strategy, []},
      starting_balance: 100_000.0
    )

    # Get comprehensive summary
    summary = ExPostFacto.Result.comprehensive_summary(output.result)

    # Display results
    display_comprehensive_results(summary)
  end

  defp generate_sample_data do
    # Generate 100 days of sample price data with some volatility
    1..100
    |> Enum.reduce({[], 100.0}, fn day, {data, last_price} ->
      # Random walk with slight upward bias
      change = (:rand.uniform() - 0.45) * 2.0  # Slight positive bias
      new_price = last_price + change

      # Create OHLC data
      high = new_price + :rand.uniform() * 0.5
      low = new_price - :rand.uniform() * 0.5
      open = last_price + (:rand.uniform() - 0.5) * 0.3
      close = new_price

      candle = %{
        high: high,
        low: low,
        open: open,
        close: close,
        volume: 1000.0 + :rand.uniform() * 500,
        timestamp: Date.add(~D[2023-01-01], day - 1) |> Date.to_string()
      }

      {[candle | data], new_price}
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp display_comprehensive_results(summary) do
    IO.puts("\n📈 COMPREHENSIVE BACKTEST RESULTS")
    IO.puts("=" |> String.duplicate(50))

    # Basic Performance
    IO.puts("\n🎯 BASIC PERFORMANCE")
    IO.puts("   Starting Balance:     $#{format_currency(summary.starting_balance)}")
    IO.puts("   Final Balance:        $#{format_currency(summary.final_balance)}")
    IO.puts("   Total P&L:            $#{format_currency(summary.total_profit_and_loss)}")
    IO.puts("   Total Return:         #{format_percentage(summary.total_return_pct)}")
    IO.puts("   CAGR:                 #{format_percentage(summary.cagr_pct)}")
    IO.puts("   Duration:             #{summary.duration_days} days")
    IO.puts("   Total Trades:         #{summary.trades_count}")

    # Risk Metrics
    IO.puts("\n⚠️  RISK METRICS")
    IO.puts("   Sharpe Ratio:         #{format_ratio(summary.sharpe_ratio)}")
    IO.puts("   Sortino Ratio:        #{format_ratio(summary.sortino_ratio)}")
    IO.puts("   Calmar Ratio:         #{format_ratio(summary.calmar_ratio)}")
    IO.puts("   Annual Volatility:    #{format_percentage(summary.annual_volatility)}")
    IO.puts("   Max Drawdown:         #{format_percentage(summary.max_drawdown_pct)}")
    IO.puts("   Max DD Duration:      #{summary.max_drawdown_duration_days} days")
    IO.puts("   Avg Drawdown:         #{format_percentage(summary.average_drawdown_pct)}")

    # Trading Performance
    IO.puts("\n📊 TRADING PERFORMANCE")
    IO.puts("   Win Rate:             #{format_percentage(summary.win_rate)}")
    IO.puts("   Winning Trades:       #{summary.win_count}")
    IO.puts("   Profit Factor:        #{format_ratio(summary.profit_factor)}")
    IO.puts("   Expectancy:           $#{format_currency(summary.expectancy)}")
    IO.puts("   Expectancy %:         #{format_percentage(summary.expectancy_pct)}")

    # Trade Analysis
    IO.puts("\n🔍 TRADE ANALYSIS")
    IO.puts("   Best Trade:           #{format_percentage(summary.best_trade_pct)}")
    IO.puts("   Worst Trade:          #{format_percentage(summary.worst_trade_pct)}")
    IO.puts("   Avg Trade:            #{format_percentage(summary.average_trade_pct)}")
    IO.puts("   Max Trade Duration:   #{summary.max_trade_duration_days} days")
    IO.puts("   Avg Trade Duration:   #{Float.round(summary.average_trade_duration_days, 1)} days")

    # Profit/Loss Breakdown
    IO.puts("\n💰 PROFIT/LOSS BREAKDOWN")
    IO.puts("   Gross Profit:         $#{format_currency(summary.gross_profit)}")
    IO.puts("   Gross Loss:           $#{format_currency(summary.gross_loss)}")
    IO.puts("   Avg Winning Trade:    $#{format_currency(summary.average_winning_trade)}")
    IO.puts("   Avg Losing Trade:     $#{format_currency(summary.average_losing_trade)}")
    IO.puts("   Largest Win:          $#{format_currency(summary.largest_winning_trade)}")
    IO.puts("   Largest Loss:         $#{format_currency(summary.largest_losing_trade)}")

    # System Quality
    IO.puts("\n🎲 SYSTEM QUALITY")
    IO.puts("   SQN:                  #{format_ratio(summary.sqn)}")
    IO.puts("   SQN Rating:           #{summary.sqn_interpretation}")

    # Position Sizing
    IO.puts("\n💼 POSITION SIZING")
    IO.puts("   Kelly Criterion:      #{format_percentage(summary.kelly_criterion * 100)}")
    IO.puts("   Kelly Rating:         #{summary.kelly_interpretation}")

    # Market Risk (vs benchmark)
    IO.puts("\n🏛️  MARKET RISK ANALYSIS")
    IO.puts("   Alpha:                #{format_percentage(summary.alpha)}")
    IO.puts("   Beta:                 #{format_ratio(summary.beta)}")
    IO.puts("   Information Ratio:    #{format_ratio(summary.information_ratio)}")
    IO.puts("   Tracking Error:       #{format_percentage(summary.tracking_error)}")
    IO.puts("   Market Correlation:   #{format_ratio(summary.market_correlation)}")

    IO.puts("\n" <> "=" |> String.duplicate(50))
    IO.puts("✅ Analysis complete! These metrics provide professional-grade")
    IO.puts("   insights into your trading strategy's performance.")
    IO.puts("\n💡 Key insights:")
    provide_key_insights(summary)
  end

  defp provide_key_insights(summary) do
    insights = []

    insights = if summary.sharpe_ratio > 1.0 do
      [" • Excellent risk-adjusted returns (Sharpe > 1.0)" | insights]
    else
      [" • Consider improving risk-adjusted returns (Sharpe < 1.0)" | insights]
    end

    insights = if summary.profit_factor > 1.5 do
      [" • Strong profit factor indicates good strategy edge" | insights]
    else
      [" • Profit factor suggests room for improvement" | insights]
    end

    insights = if summary.max_drawdown_pct < -20.0 do
      [" • High maximum drawdown - consider risk management" | insights]
    else
      [" • Reasonable drawdown control" | insights]
    end

    insights = case summary.sqn do
      sqn when sqn > 2.5 -> [" • Excellent system quality (SQN > 2.5)" | insights]
      sqn when sqn > 1.6 -> [" • Good system quality (SQN > 1.6)" | insights]
      _ -> [" • Consider strategy improvements (low SQN)" | insights]
    end

    insights
    |> Enum.reverse()
    |> Enum.each(&IO.puts/1)
  end

  # Formatting helpers
  defp format_currency(amount) when is_float(amount) do
    amount |> Float.round(2) |> :erlang.float_to_binary(decimals: 2)
  end
  defp format_currency(amount), do: "#{amount}"

  defp format_percentage(pct) when is_float(pct) do
    "#{Float.round(pct, 2)}%"
  end
  defp format_percentage(pct), do: "#{pct}%"

  defp format_ratio(ratio) when is_float(ratio) do
    Float.round(ratio, 3) |> :erlang.float_to_binary(decimals: 3)
  end
  defp format_ratio(:infinity), do: "∞"
  defp format_ratio(ratio), do: "#{ratio}"
end

# Run the demo
ComprehensiveStatsDemo.run_demo()
