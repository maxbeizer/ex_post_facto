defmodule ExPostFacto.ExampleStrategies.BuyBuyBuy do
  @moduledoc false

  @doc false
  @spec call(any()) :: :buy | :close
  # Special case to close position
  def call(%{high: high}) when high >= 100, do: :close_buy
  def call(_), do: :buy
end
