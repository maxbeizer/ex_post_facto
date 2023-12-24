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
  def calculate!(%{trade_pairs: _trade_pairs}) do
    0.0
  end
end
