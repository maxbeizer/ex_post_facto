defmodule ExPostFacto.ExampleStrategies.SimpleBuyHold do
  @moduledoc """
  Simple buy and hold strategy using the enhanced Strategy behaviour.

  This strategy simply buys on the first data point and holds the position.
  """

  use ExPostFacto.Strategy

  def init(opts) do
    max_trades = Keyword.get(opts, :max_trades, 1)
    {:ok, %{trades_made: 0, max_trades: max_trades}}
  end

  def next(state) do
    current_position = position()

    if state.trades_made < state.max_trades and current_position == :none do
      buy()
      {:ok, %{state | trades_made: state.trades_made + 1}}
    else
      {:ok, state}
    end
  end
end
