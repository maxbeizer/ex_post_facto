defmodule ExPostFacto.TradeStats.BestTradeByPercentage do
  @moduledoc """
  This module calculates the best trade by percentage from the compiled pairs.
  """

  alias ExPostFacto.TradeStats.TradePair

  @spec calculate!(result :: Result.t()) :: float()
  def calculate!(%{trade_pairs: []}), do: 0.0

  def calculate!(%{trade_pairs: trade_pairs}) do
    trade_pairs
    |> Enum.map(&TradePair.result_percentage/1)
    |> Enum.max()
  end
end
