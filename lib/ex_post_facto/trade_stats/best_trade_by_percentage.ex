defmodule ExPostFacto.TradeStats.BestTradeByPercentage do
  @moduledoc """
  This module calculates the best trade by percentage from the compiled pairs.
  """

  alias ExPostFacto.{
    DataPoint,
    Result
  }

  alias ExPostFacto.Result.{
    ResultCalculationError
  }

  @spec calculate!(result :: Result.t()) :: float()
  def calculate!(%Result{trade_pairs: trade_pairs, total_profit_and_loss: total_profit_and_loss}) do
    trade_pairs
    |> Enum.reduce(%{balance: total_profit_and_loss, max: 0.0}, fn pair, acc ->
      {percentage, balance} = trade_percentage(pair, total_profit_and_loss)
      new_max = max(acc[:max], percentage)
      %{acc | balance: balance, max: new_max}
    end)
    |> Map.get(:max)
  end

  @spec trade_percentage(
          pair :: {
            enter_point :: %DataPoint{},
            exit_point :: %DataPoint{}
          },
          balance :: float()
        ) :: {float(), float()}
  defp trade_percentage(_, 0.0), do: {0.0, 0.0}

  defp trade_percentage(
         {%{datum: %{open: exit_open}}, %{datum: %{open: enter_open}, action: enter_action}},
         balance
       ) do
    case enter_action do
      :buy ->
        p_or_l = exit_open - enter_open
        {100 * p_or_l / balance, balance + -p_or_l}

      :sell ->
        p_or_l = enter_open - exit_open
        {100 * p_or_l / balance, balance + -p_or_l}

      _ ->
        raise ResultCalculationError,
              "Unknown action: #{inspect(enter_action)}"
    end
  end
end
