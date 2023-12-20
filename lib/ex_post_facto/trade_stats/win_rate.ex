defmodule ExPostFacto.TradeStats.WinRate do
  @moduledoc """
  Calculates the win rate for a result based on data points
  """
  alias ExPostFacto.{
    DataPoint,
    Result
  }

  @spec calculate!(result :: %Result{}) :: float() | no_return()
  def calculate!(%{trades_count: 0}), do: 0.0

  def calculate!(%{trades_count: trades_count, trade_pairs: trade_pairs}) do
    win_count =
      trade_pairs
      |> Enum.reduce(0, &calculate_win_count/2)

    win_count / trades_count * 100.0
  end

  @spec calculate_win_count(
          trade_pair :: {%DataPoint{}, %DataPoint{}},
          win_count :: non_neg_integer()
        ) ::
          non_neg_integer()
  defp calculate_win_count(
         {%{datum: %{open: exit_price}}, %{datum: %{open: enter_price}, action: :buy}},
         win_count
       ) do
    cond do
      exit_price > enter_price ->
        win_count + 1

      exit_price < enter_price ->
        win_count

      exit_price == enter_price ->
        win_count
    end
  end

  defp calculate_win_count(
         {%{datum: %{open: exit_price}}, %{datum: %{open: enter_price}, action: :sell}},
         win_count
       ) do
    cond do
      exit_price < enter_price ->
        win_count + 1

      exit_price > enter_price ->
        win_count

      exit_price == enter_price ->
        win_count
    end
  end
end
