defmodule ExPostFacto.ExampleStrategies.SellSellSell do
  @moduledoc false

  @doc false
  @spec call(any()) :: :sell | :close
  # Special case to close position
  def call(%{high: high}) when high >= 100, do: :close_sell
  def call(_), do: :sell
end
