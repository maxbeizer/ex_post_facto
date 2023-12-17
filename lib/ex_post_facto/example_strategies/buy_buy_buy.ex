defmodule ExPostFacto.ExampleStrategies.BuyBuyBuy do
  @moduledoc false

  @doc false
  @spec call(any(), any() | nil) :: :buy | :close
  # Special case to close position
  def call(%{high: high}, _) when high >= 100, do: :close_buy
  def call(_, _), do: :buy
end
