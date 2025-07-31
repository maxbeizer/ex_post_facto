defmodule ExPostFacto.TradeStats.MarketRisk do
  @moduledoc """
  Calculates market risk metrics for trading performance analysis.

  This module provides calculations for:
  - Alpha: Excess return over what would be expected given the market's performance
  - Beta: Sensitivity of the strategy to market movements
  - Correlation: Correlation coefficient with market benchmark
  - Tracking Error: Standard deviation of excess returns
  - Information Ratio: Alpha divided by tracking error

  Note: These calculations require benchmark market data for comparison.
  If no benchmark data is provided, simplified calculations are used.
  """

  alias ExPostFacto.Result

  @doc """
  Calculates Alpha - the excess return over the expected return based on beta.

  Alpha = Strategy Return - (Risk Free Rate + Beta * (Market Return - Risk Free Rate))

  ## Parameters
  - result: The backtest result
  - benchmark_return: Annual return of the benchmark (e.g., S&P 500)
  - risk_free_rate: Risk-free rate (default: 0.02 for 2%)

  ## Returns
  Float representing alpha as a percentage
  """
  @spec alpha(result :: %Result{}, benchmark_return :: float(), risk_free_rate :: float()) ::
          float()
  def alpha(result, benchmark_return, risk_free_rate \\ 0.02) do
    # Convert to decimal
    strategy_return = annual_return(result) / 100
    beta_value = beta(result, benchmark_return, risk_free_rate)

    expected_return = risk_free_rate + beta_value * (benchmark_return / 100 - risk_free_rate)

    # Convert back to percentage
    (strategy_return - expected_return) * 100
  end

  @doc """
  Calculates Beta - the sensitivity to market movements.

  Beta = Covariance(Strategy Returns, Market Returns) / Variance(Market Returns)

  ## Parameters
  - result: The backtest result
  - benchmark_return: Annual return of the benchmark
  - risk_free_rate: Risk-free rate (default: 0.02 for 2%)

  ## Returns
  Float representing beta
  - Beta = 1.0: Same volatility as market
  - Beta > 1.0: More volatile than market
  - Beta < 1.0: Less volatile than market
  """
  @spec beta(result :: %Result{}, benchmark_return :: float(), risk_free_rate :: float()) ::
          float()
  def beta(result, _benchmark_return, _risk_free_rate \\ 0.02) do
    # Simplified beta calculation when we don't have time-series benchmark data
    # In practice, you'd need daily/periodic returns for both strategy and benchmark

    _strategy_return = annual_return(result)
    strategy_volatility = annual_volatility(result)

    # Estimate market volatility (typical S&P 500 volatility is around 15-20%)
    estimated_market_volatility = 18.0

    cond do
      strategy_volatility == 0.0 ->
        0.0

      estimated_market_volatility == 0.0 ->
        0.0

      true ->
        # Simplified calculation: assume some correlation with market
        # This would be more accurate with actual time-series data
        correlation = estimate_market_correlation(result)
        correlation * strategy_volatility / estimated_market_volatility
    end
  end

  @doc """
  Calculates the correlation coefficient with the market.

  ## Parameters
  - result: The backtest result

  ## Returns
  Float representing correlation (-1.0 to 1.0)
  """
  @spec market_correlation(result :: %Result{}) :: float()
  def market_correlation(result) do
    estimate_market_correlation(result)
  end

  @doc """
  Calculates tracking error - the standard deviation of excess returns.

  Tracking Error = Standard Deviation(Strategy Returns - Benchmark Returns)

  ## Parameters
  - result: The backtest result
  - benchmark_return: Annual return of the benchmark

  ## Returns
  Float representing tracking error as a percentage
  """
  @spec tracking_error(result :: %Result{}, benchmark_return :: float()) :: float()
  def tracking_error(result, benchmark_return) do
    strategy_return = annual_return(result)
    _excess_return = strategy_return - benchmark_return

    # Simplified calculation - in practice you'd need periodic returns
    # Estimate based on volatility and correlation
    strategy_volatility = annual_volatility(result)
    correlation = market_correlation(result)

    # Tracking error approximation
    strategy_volatility * :math.sqrt(2 * (1 - correlation))
  end

  @doc """
  Calculates Information Ratio - risk-adjusted measure of active return.

  Information Ratio = Alpha / Tracking Error

  ## Parameters
  - result: The backtest result
  - benchmark_return: Annual return of the benchmark
  - risk_free_rate: Risk-free rate (default: 0.02 for 2%)

  ## Returns
  Float representing information ratio
  """
  @spec information_ratio(
          result :: %Result{},
          benchmark_return :: float(),
          risk_free_rate :: float()
        ) :: float()
  def information_ratio(result, benchmark_return, risk_free_rate \\ 0.02) do
    alpha_value = alpha(result, benchmark_return, risk_free_rate)
    tracking_error_value = tracking_error(result, benchmark_return)

    if tracking_error_value == 0.0 do
      0.0
    else
      alpha_value / tracking_error_value
    end
  end

  @doc """
  Calculates the maximum drawdown relative to the benchmark.

  ## Parameters
  - result: The backtest result
  - benchmark_max_drawdown: Maximum drawdown of the benchmark

  ## Returns
  Float representing relative drawdown
  """
  @spec relative_drawdown(result :: %Result{}, benchmark_max_drawdown :: float()) :: float()
  def relative_drawdown(result, benchmark_max_drawdown) do
    result.max_draw_down_percentage - benchmark_max_drawdown
  end

  # Private helper functions

  @spec annual_return(result :: %Result{}) :: float()
  defp annual_return(%{starting_balance: starting_balance}) when starting_balance == 0.0, do: 0.0

  defp annual_return(result) do
    final_value = result.starting_balance + result.total_profit_and_loss
    initial_value = result.starting_balance

    cond do
      is_nil(result.duration) ->
        0.0

      result.duration == 0.0 ->
        0.0

      true ->
        years = result.duration / 365.25

        if years == 0.0 do
          0.0
        else
          (:math.pow(final_value / initial_value, 1 / years) - 1) * 100
        end
    end
  end

  @spec annual_volatility(result :: %Result{}) :: float()
  defp annual_volatility(result) do
    # This would be more accurate with periodic returns
    # For now, estimate based on trade variability

    case result.trades_count do
      0 ->
        0.0

      count when count < 2 ->
        0.0

      _ ->
        trade_returns =
          Enum.map(result.trade_pairs, fn trade_pair ->
            if trade_pair.previous_balance == 0.0 do
              0.0
            else
              (trade_pair.balance - trade_pair.previous_balance) / trade_pair.previous_balance *
                100
            end
          end)

        mean_return = Enum.sum(trade_returns) / length(trade_returns)

        variance =
          trade_returns
          |> Enum.map(fn return -> :math.pow(return - mean_return, 2) end)
          |> Enum.sum()
          |> Kernel./(length(trade_returns) - 1)

        volatility = :math.sqrt(variance)

        # Annualize (simplified)
        trade_frequency =
          if result.duration == 0.0 or is_nil(result.duration) do
            1.0
          else
            length(trade_returns) / (result.duration / 365.25)
          end

        volatility * :math.sqrt(trade_frequency)
    end
  end

  @spec estimate_market_correlation(result :: %Result{}) :: float()
  defp estimate_market_correlation(result) do
    # Simplified correlation estimation
    # In practice, this would be calculated from actual return correlations

    # Estimate based on strategy characteristics:
    # - High Sharpe ratio strategies often have lower correlation
    # - More volatile strategies might have higher correlation

    strategy_volatility = annual_volatility(result)

    case strategy_volatility do
      # Low volatility = likely market-neutral
      vol when vol < 10.0 -> 0.3
      # Moderate volatility = some market exposure
      vol when vol < 20.0 -> 0.6
      # High volatility = likely market-correlated
      vol when vol < 30.0 -> 0.8
      # Very high volatility = highly correlated
      _ -> 0.9
    end
  end
end
