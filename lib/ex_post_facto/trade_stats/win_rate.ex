defmodule ExPostFacto.TradeStats.WinRate do
  @moduledoc """
  Calculates the win rate for a result based on data points
  """
  alias ExPostFacto.Result
  alias ExPostFacto.TradeStats.TradePair

  @spec calculate!(result :: %Result{}) :: float() | no_return()
  def calculate!(%{trades_count: 0}), do: 0.0

  def calculate!(%{trades_count: trades_count, trade_pairs: trade_pairs}) do
    win_count =
      trade_pairs
      |> calculate_win_count!()

    win_count / trades_count * 100.0
  end

  @spec calculate_win_count!(trade_pairs :: [TradePair.t()]) :: non_neg_integer()
  def calculate_win_count!(trade_pairs) do
    Enum.reduce(trade_pairs, 0, fn trade_pair, win_count ->
      case TradePair.result(trade_pair) do
        :win -> win_count + 1
        :loss -> win_count
        :break_even -> win_count
      end
    end)
  end
end
