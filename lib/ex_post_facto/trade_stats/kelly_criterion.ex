defmodule ExPostFacto.TradeStats.KellyCriterion do
  @moduledoc """
  Calculates the Kelly Criterion for optimal position sizing.

  The Kelly Criterion helps determine the optimal fraction of capital to risk
  on each trade to maximize long-term growth while minimizing the risk of ruin.

  Kelly % = (bp - q) / b

  Where:
  - b = odds of winning (average win / average loss)
  - p = probability of winning (win rate)
  - q = probability of losing (1 - p)

  Kelly Criterion interpretation:
  - Positive value: Suggests the strategy has an edge
  - Negative value: Suggests the strategy should be avoided
  - 0.25 (25%): Optimal fraction of capital to risk per trade
  - Above 0.40: Usually considered too aggressive
  """

  alias ExPostFacto.Result
  alias ExPostFacto.TradeStats.{TradePair, ProfitMetrics}

  @doc """
  Calculates the Kelly Criterion percentage.

  ## Parameters
  - result: The backtest result containing trade pairs

  ## Returns
  Float representing the optimal fraction of capital to risk (0.25 = 25%)
  """
  @spec kelly_criterion(result :: %Result{}) :: float()
  def kelly_criterion(%{trades_count: 0}), do: 0.0

  def kelly_criterion(result) do
    win_rate = result.win_rate / 100  # Convert percentage to decimal
    loss_rate = 1 - win_rate

    average_win = ProfitMetrics.average_winning_trade(result)
    average_loss = abs(ProfitMetrics.average_losing_trade(result))

    cond do
      average_win == 0.0 -> 0.0
      average_loss == 0.0 -> 0.0
      loss_rate == 0.0 -> 0.0
      true ->
        odds_ratio = average_win / average_loss
        (odds_ratio * win_rate - loss_rate) / odds_ratio
    end
  end

  @doc """
  Calculates a fractional Kelly criterion for more conservative position sizing.

  Many traders use a fraction of the Kelly percentage (e.g., 1/2 Kelly, 1/4 Kelly)
  to reduce volatility while still capturing most of the growth benefit.

  ## Parameters
  - result: The backtest result containing trade pairs
  - fraction: Fraction of Kelly to use (default: 0.25 for quarter Kelly)

  ## Returns
  Float representing the fractional Kelly percentage
  """
  @spec fractional_kelly(result :: %Result{}, fraction :: float()) :: float()
  def fractional_kelly(result, fraction \\ 0.25) do
    kelly_criterion(result) * fraction
  end

  @doc """
  Returns a textual interpretation of the Kelly Criterion value.
  """
  @spec kelly_interpretation(kelly :: float()) :: String.t()
  def kelly_interpretation(kelly) when kelly <= 0.0, do: "No edge - avoid this strategy"
  def kelly_interpretation(kelly) when kelly <= 0.10, do: "Weak edge - use small position sizes"
  def kelly_interpretation(kelly) when kelly <= 0.25, do: "Moderate edge - reasonable strategy"
  def kelly_interpretation(kelly) when kelly <= 0.40, do: "Strong edge - good strategy"
  def kelly_interpretation(_kelly), do: "Very strong edge - potentially too aggressive"

  @doc """
  Calculates the optimal position size in dollar terms based on Kelly Criterion.

  ## Parameters
  - result: The backtest result containing trade pairs
  - current_capital: Current available capital
  - fraction: Fraction of Kelly to use (default: 0.25)

  ## Returns
  Float representing the optimal position size in dollars
  """
  @spec optimal_position_size(result :: %Result{}, current_capital :: float(), fraction :: float()) :: float()
  def optimal_position_size(result, current_capital, fraction \\ 0.25) do
    kelly_fraction = fractional_kelly(result, fraction)
    current_capital * kelly_fraction
  end

  @doc """
  Calculates the geometric mean return for the strategy.

  This is useful for understanding the expected compound growth rate
  when using Kelly sizing.
  """
  @spec geometric_mean_return(result :: %Result{}) :: float()
  def geometric_mean_return(%{trades_count: 0}), do: 0.0

  def geometric_mean_return(result) do
    returns =
      result.trade_pairs
      |> Enum.map(&TradePair.result_percentage/1)
      |> Enum.map(fn percentage -> 1 + (percentage / 100) end)  # Convert to growth factors

    case length(returns) do
      0 -> 0.0
      count ->
        geometric_mean =
          returns
          |> Enum.reduce(1.0, &(&1 * &2))
          |> :math.pow(1 / count)

        (geometric_mean - 1) * 100  # Convert back to percentage
    end
  end

  @doc """
  Calculates the risk of ruin probability using simplified Kelly analysis.

  This gives an estimate of the probability of losing all capital
  if the current strategy continues indefinitely.
  """
  @spec risk_of_ruin(result :: %Result{}, drawdown_limit :: float()) :: float()
  def risk_of_ruin(result, drawdown_limit \\ 0.20) do
    kelly = kelly_criterion(result)

    if kelly <= 0.0 do
      1.0  # Negative edge = certain ruin
    else
      # Simplified risk of ruin calculation
      # In practice, this would use more sophisticated formulas
      win_rate = result.win_rate / 100
      average_win_pct = if result.trades_count > 0 do
        result.best_trade_by_percentage
      else
        0.0
      end

      average_loss_pct = abs(result.worst_trade_by_percentage)

      cond do
        average_win_pct == 0.0 -> 1.0
        average_loss_pct == 0.0 -> 0.0
        true ->
          # Simplified calculation based on win rate and average outcomes
          risk_ratio = average_loss_pct / average_win_pct
          base_risk = :math.pow(risk_ratio, win_rate)

          # Adjust for drawdown limit
          min(base_risk / (1 - drawdown_limit), 1.0)
      end
    end
  end
end
