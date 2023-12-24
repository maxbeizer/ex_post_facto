defmodule ExPostFacto.TradeStats.TradeDuration do
  @moduledoc """
  This module calculates the max/average trade duration for a list of compiled
  pairs.
  """

  alias ExPostFacto.Result
  alias ExPostFacto.TradeStats.TradePair

  @spec max!(result :: Result.t()) :: float()
  def max!(%{trade_pairs: []}), do: 0.0

  def max!(%{trade_pairs: trade_pairs}) do
    trade_pairs
    |> Enum.map(&TradePair.duration/1)
    |> Enum.max()
  end

  @spec average!(result :: Result.t()) :: float()
  def average!(%{trade_pairs: []}), do: 0.0

  def average!(%{trade_pairs: trade_pairs}) do
    trade_pairs
    |> Enum.map(&TradePair.duration/1)
    |> Enum.reduce(0.0, &(&1 + &2))
    |> (&(&1 / length(trade_pairs))).()
  end
end
