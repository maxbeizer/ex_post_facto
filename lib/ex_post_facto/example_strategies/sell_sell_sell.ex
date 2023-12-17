defmodule ExPostFacto.ExampleStrategies.SellSellSell do
  @moduledoc false

  @doc false
  @spec call(any(), any() | nil) :: :sell | :close
  # Special case to close position
  def call(%{high: high}, _) when high >= 100, do: :close_sell
  def call(_, _), do: :sell
end
