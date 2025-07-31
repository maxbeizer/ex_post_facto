defmodule ExPostFacto.TradeStats.SystemQuality do
  @moduledoc """
  Calculates the System Quality Number (SQN) for trading performance analysis.

  The SQN measures the quality of a trading system by analyzing the distribution
  of trade results. It was developed by Van Tharp and is used to evaluate
  whether a trading system's performance is due to skill or luck.

  SQN = (Average Trade Result / Standard Deviation of Trade Results) * sqrt(Number of Trades)

  SQN Interpretation:
  - Below 1.6: Poor system
  - 1.6 to 1.9: Below average but tradeable
  - 2.0 to 2.4: Average system
  - 2.5 to 2.9: Good system
  - 3.0 to 5.0: Excellent system
  - 5.0 to 6.9: Superb system
  - Above 7.0: Too good to be true (likely curve-fitted)
  """

  alias ExPostFacto.Result
  alias ExPostFacto.TradeStats.TradePair

  @doc """
  Calculates the System Quality Number (SQN).

  ## Parameters
  - result: The backtest result containing trade pairs

  ## Returns
  Float representing the SQN value
  """
  @spec system_quality_number(result :: %Result{}) :: float()
  def system_quality_number(%{trades_count: 0}), do: 0.0
  def system_quality_number(%{trades_count: 1}), do: 0.0

  def system_quality_number(result) do
    trade_results = get_trade_results(result)

    if length(trade_results) < 2 do
      0.0
    else
      count = length(trade_results)
      average_result = Enum.sum(trade_results) / count
      std_deviation = standard_deviation(trade_results, average_result)

      if std_deviation == 0.0 do
        0.0
      else
        average_result / std_deviation * :math.sqrt(count)
      end
    end
  end

  @doc """
  Returns a textual interpretation of the SQN value.
  """
  @spec sqn_interpretation(sqn :: float()) :: String.t()
  def sqn_interpretation(sqn) when sqn < 1.6, do: "Poor system"
  def sqn_interpretation(sqn) when sqn < 2.0, do: "Below average but tradeable"
  def sqn_interpretation(sqn) when sqn < 2.5, do: "Average system"
  def sqn_interpretation(sqn) when sqn < 3.0, do: "Good system"
  def sqn_interpretation(sqn) when sqn < 5.0, do: "Excellent system"
  def sqn_interpretation(sqn) when sqn < 7.0, do: "Superb system"
  def sqn_interpretation(_sqn), do: "Too good to be true (likely curve-fitted)"

  @doc """
  Calculates the confidence level for the SQN.

  Higher confidence levels indicate more reliable results.
  """
  @spec confidence_level(result :: %Result{}) :: float()
  def confidence_level(%{trades_count: count}) when count < 30, do: 0.0

  def confidence_level(result) do
    sqn = system_quality_number(result)

    # Simplified confidence calculation based on SQN and sample size
    # In practice, this would use more sophisticated statistical methods
    base_confidence =
      case sqn do
        sqn when sqn >= 2.0 -> 0.95
        sqn when sqn >= 1.6 -> 0.80
        sqn when sqn >= 1.0 -> 0.60
        _ -> 0.30
      end

    # Adjust for sample size
    sample_adjustment = min(result.trades_count / 100, 1.0)
    base_confidence * sample_adjustment
  end

  # Private helper functions

  @spec get_trade_results(result :: %Result{}) :: [float()]
  defp get_trade_results(result) do
    Enum.map(result.trade_pairs, &TradePair.result_value/1)
  end

  @spec standard_deviation(values :: [float()], mean :: float()) :: float()
  defp standard_deviation(values, mean) do
    variance =
      values
      |> Enum.map(fn value -> :math.pow(value - mean, 2) end)
      |> Enum.sum()
      |> Kernel./(length(values) - 1)

    :math.sqrt(variance)
  end
end
