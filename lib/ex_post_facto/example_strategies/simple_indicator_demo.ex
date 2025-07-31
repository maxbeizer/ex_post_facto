defmodule ExPostFacto.ExampleStrategies.SimpleIndicatorDemo do
  @moduledoc """
  Simple demonstration strategy showing the indicator framework usage.

  This strategy demonstrates:
  - Basic indicator calculations (SMA, EMA)
  - Crossover detection
  - Clean integration with the Strategy behaviour

  ## Trading Rules

  - Buy when fast EMA crosses above slow SMA
  - Sell when fast EMA crosses below slow SMA
  """

  use ExPostFacto.Strategy

  def init(opts) do
    fast_period = Keyword.get(opts, :fast_period, 10)
    slow_period = Keyword.get(opts, :slow_period, 20)

    {:ok,
     %{
       fast_period: fast_period,
       slow_period: slow_period,
       price_history: []
     }}
  end

  def next(state) do
    current_price = data().close

    # Update price history (keep last 50 for efficiency)
    updated_history = [current_price | state.price_history] |> Enum.take(50)

    # Calculate indicators using the framework
    fast_ema = indicator(:ema, updated_history, state.fast_period)
    slow_ema = indicator(:ema, updated_history, state.slow_period)

    # Make trading decisions based on crossovers
    cond do
      crossover?(fast_ema, slow_ema) ->
        buy()

      crossunder?(fast_ema, slow_ema) ->
        sell()

      true ->
        :no_action
    end

    {:ok, %{state | price_history: updated_history}}
  end
end
