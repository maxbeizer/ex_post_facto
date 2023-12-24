defmodule ExPostFacto.TradeStats.TradePercentage do
  @moduledoc """
  This module calculates the best/worst/average trade by percentage from the
  compiled pairs.
  """

  alias ExPostFacto.TradeStats.TradePair

  @spec best!(result :: Result.t()) :: float()
  def best!(%{trade_pairs: []}), do: 0.0

  def best!(%{trade_pairs: trade_pairs}) do
    trade_pairs
    |> Enum.map(&TradePair.result_percentage/1)
    |> Enum.max()
  end

  @spec worst!(result :: Result.t()) :: float()
  def worst!(%{trade_pairs: []}), do: 0.0

  def worst!(%{trade_pairs: trade_pairs}) do
    trade_pairs
    |> Enum.map(&TradePair.result_percentage/1)
    |> Enum.min()
  end

  @spec average!(result :: Result.t()) :: float()
  def average!(%{trade_pairs: []}), do: 0.0

  def average!(%{trade_pairs: trade_pairs}) do
    trade_pairs
    |> Enum.map(&TradePair.result_value/1)
    |> Enum.reduce(0.0, &(&1 + &2))
    |> (&(&1 / length(trade_pairs))).()
  end
end
