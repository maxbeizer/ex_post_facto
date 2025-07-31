defmodule ExPostFacto.TradeStats.FinancialRatios do
  @moduledoc """
  Calculates various financial ratios for trading performance analysis.

  This module provides calculations for:
  - Sharpe Ratio: Risk-adjusted return relative to risk-free rate
  - Sortino Ratio: Risk-adjusted return relative to downside volatility
  - Calmar Ratio: Annual return relative to maximum drawdown
  """

  alias ExPostFacto.Result
  alias ExPostFacto.TradeStats.TradePair

  @doc """
  Calculates the Sharpe ratio.

  Sharpe Ratio = (Annual Return - Risk Free Rate) / Annual Volatility

  ## Parameters
  - result: The backtest result containing trade pairs
  - risk_free_rate: Annual risk-free rate (default: 0.02 for 2%)

  ## Returns
  Float representing the Sharpe ratio
  """
  @spec sharpe_ratio(result :: %Result{}, risk_free_rate :: float()) :: float()
  def sharpe_ratio(result, risk_free_rate \\ 0.02) do
    annual_return = annual_return_percentage(result)
    annual_volatility = annual_volatility(result)

    case annual_volatility do
      0.0 -> 0.0
      _ -> (annual_return - risk_free_rate * 100) / annual_volatility
    end
  end

  @doc """
  Calculates the Sortino ratio.

  Sortino Ratio = (Annual Return - Risk Free Rate) / Downside Volatility

  Similar to Sharpe ratio but only considers downside volatility (negative returns).
  """
  @spec sortino_ratio(result :: %Result{}, risk_free_rate :: float()) :: float()
  def sortino_ratio(result, risk_free_rate \\ 0.02) do
    annual_return = annual_return_percentage(result)
    downside_volatility = downside_volatility(result)

    case downside_volatility do
      0.0 -> 0.0
      _ -> (annual_return - risk_free_rate * 100) / downside_volatility
    end
  end

  @doc """
  Calculates the Calmar ratio.

  Calmar Ratio = Annual Return / |Maximum Drawdown|
  """
  @spec calmar_ratio(result :: %Result{}) :: float()
  def calmar_ratio(result) do
    annual_return = annual_return_percentage(result)
    max_drawdown = abs(result.max_draw_down_percentage)

    case max_drawdown do
      0.0 -> 0.0
      _ -> annual_return / max_drawdown
    end
  end

  @doc """
  Calculates the annual return percentage.

  Annual Return = ((Final Value / Initial Value) ^ (365.25 / Days)) - 1) * 100
  """
  @spec annual_return_percentage(result :: %Result{}) :: float()
  def annual_return_percentage(%{starting_balance: starting_balance, duration: duration})
      when starting_balance == 0.0 or is_nil(duration) or duration == 0.0 do
    0.0
  end

  def annual_return_percentage(result) do
    final_value = result.starting_balance + result.total_profit_and_loss
    initial_value = result.starting_balance
    years = result.duration / 365.25

    case years do
      0.0 -> 0.0
      _ -> (:math.pow(final_value / initial_value, 1 / years) - 1) * 100
    end
  end

  @doc """
  Calculates the total return percentage.

  Total Return = ((Final Value - Initial Value) / Initial Value) * 100
  """
  @spec total_return_percentage(result :: %Result{}) :: float()
  def total_return_percentage(%{starting_balance: 0.0}), do: 0.0

  def total_return_percentage(result) do
    (result.total_profit_and_loss / result.starting_balance) * 100
  end

  @doc """
  Calculates annualized volatility based on trade returns.
  """
  @spec annual_volatility(result :: %Result{}) :: float()
  def annual_volatility(result) do
    trade_returns = get_trade_return_percentages(result)

    case length(trade_returns) do
      0 -> 0.0
      1 -> 0.0
      _ ->
        mean_return = Enum.sum(trade_returns) / length(trade_returns)

        variance =
          trade_returns
          |> Enum.map(fn return -> :math.pow(return - mean_return, 2) end)
          |> Enum.sum()
          |> Kernel./(length(trade_returns) - 1)

        volatility = :math.sqrt(variance)

        # Annualize assuming trades represent periods (adjust factor as needed)
        # This is a simplified calculation - in practice you'd need more sophisticated
        # time-series analysis
        trade_frequency = case result.duration do
          0.0 -> 1.0
          nil -> 1.0
          duration -> length(trade_returns) / (duration / 365.25)
        end

        volatility * :math.sqrt(trade_frequency)
    end
  end

  @doc """
  Calculates downside volatility (volatility of negative returns only).
  """
  @spec downside_volatility(result :: %Result{}) :: float()
  def downside_volatility(result) do
    trade_returns = get_trade_return_percentages(result)
    negative_returns = Enum.filter(trade_returns, fn return -> return < 0 end)

    case length(negative_returns) do
      0 -> 0.0
      1 -> 0.0
      _ ->
        mean_negative = Enum.sum(negative_returns) / length(negative_returns)

        variance =
          negative_returns
          |> Enum.map(fn return -> :math.pow(return - mean_negative, 2) end)
          |> Enum.sum()
          |> Kernel./(length(negative_returns) - 1)

        volatility = :math.sqrt(variance)

        # Annualize
        trade_frequency = case result.duration do
          0.0 -> 1.0
          nil -> 1.0
          duration -> length(trade_returns) / (duration / 365.25)
        end

        volatility * :math.sqrt(trade_frequency)
    end
  end

  # Private helper functions

  @spec get_trade_return_percentages(result :: %Result{}) :: [float()]
  defp get_trade_return_percentages(result) do
    Enum.map(result.trade_pairs, &TradePair.result_percentage/1)
  end
end
