defmodule ExPostFacto.TradeStats.TotalProfitAndLoss do
  @moduledoc """
  Calculates the total profit and loss for a result based on data points
  """

  alias ExPostFacto.Result.ResultCalculationError

  @doc """
  Calculates the total profit and loss for a result based on data points. When
  the number of trades is odd, i.e. there is not a close to match an open, then
  the last trade is ignored.
  """
  @spec calculate!(
          data_points :: list(),
          total_profit_and_loss :: float()
        ) :: float() | no_return()
  def calculate!([], total_profit_and_loss), do: total_profit_and_loss

  def calculate!([_single_data_point], total_profit_and_loss),
    do: total_profit_and_loss

  # The number of trades is odd, i.e. there is not a close to match an open. So
  # lop off the first one in the list, i.e. most recent.
  def calculate!([_head | rest] = data_points, total_profit_and_loss)
      when rem(length(data_points), 2) == 1 do
    calculate!(rest, total_profit_and_loss)
  end

  def calculate!([head, previous | rest], total_profit_and_loss) do
    %{datum: %{close: head_close}, action: head_action} = head
    %{datum: %{close: previous_close}, action: previous_action} = previous

    computed_profit_and_loss =
      cond do
        head_action == :close_buy and previous_action == :buy and head_close > previous_close ->
          total_profit_and_loss + head_close - previous_close

        head_action == :close_buy and previous_action == :buy and head_close < previous_close ->
          total_profit_and_loss + head_close - previous_close

        head_action == :close_buy and previous_action == :buy and head_close == previous_close ->
          total_profit_and_loss

        head_action == :close_sell and previous_action == :sell and head_close > previous_close ->
          total_profit_and_loss + previous_close - head_close

        head_action == :close_sell and previous_action == :sell and head_close < previous_close ->
          total_profit_and_loss + previous_close - head_close

        head_action == :close_sell and previous_action == :sell and head_close == previous_close ->
          total_profit_and_loss

        true ->
          raise ResultCalculationError,
                "Unknown action combination: #{inspect(head_action)} and #{inspect(previous_action)}"
      end

    calculate!(rest, computed_profit_and_loss)
  end
end
