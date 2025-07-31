defmodule ExPostFacto.ExampleStrategies.SmaStrategy do
  @moduledoc """
  Example strategy using the enhanced Strategy behaviour.

  This strategy implements a simple moving average crossover system where:
  - Buy when fast SMA crosses above slow SMA
  - Sell when fast SMA crosses below slow SMA
  """

  use ExPostFacto.Strategy

  @doc """
  Initialize the strategy with SMA periods.

  Options:
  - `:fast_period` - Period for fast moving average (default: 10)
  - `:slow_period` - Period for slow moving average (default: 20)
  """
  def init(opts) do
    fast_period = Keyword.get(opts, :fast_period, 10)
    slow_period = Keyword.get(opts, :slow_period, 20)

    if fast_period >= slow_period do
      {:error, "fast_period must be less than slow_period"}
    else
      {:ok,
       %{
         fast_period: fast_period,
         slow_period: slow_period,
         price_history: [],
         fast_sma_history: [],
         slow_sma_history: []
       }}
    end
  end

  @doc """
  Process each data point and make trading decisions.
  """
  def next(state) do
    current_data = data()
    current_price = Map.get(current_data, :close, 0.0)

    # Update price history
    updated_price_history = [current_price | state.price_history]

    # Calculate SMAs if we have enough data
    {fast_sma, slow_sma, updated_state} =
      calculate_smas(updated_price_history, state.fast_period, state.slow_period, state)

    # Make trading decisions based on SMA crossover
    make_trading_decision(fast_sma, slow_sma, updated_state)

    new_state = %{
      updated_state
      | price_history: updated_price_history,
        fast_sma_history: [fast_sma | updated_state.fast_sma_history],
        slow_sma_history: [slow_sma | updated_state.slow_sma_history]
    }

    {:ok, new_state}
  end

  # Private helper functions

  defp calculate_smas(price_history, fast_period, slow_period, state) do
    fast_sma = calculate_sma(price_history, fast_period)
    slow_sma = calculate_sma(price_history, slow_period)

    {fast_sma, slow_sma, state}
  end

  defp calculate_sma(prices, period) do
    if length(prices) >= period do
      prices
      |> Enum.take(period)
      |> Enum.sum()
      |> Kernel./(period)
    else
      0.0
    end
  end

  defp make_trading_decision(fast_sma, slow_sma, state) do
    current_position = position()

    # Check for crossovers
    fast_sma_history = [fast_sma | state.fast_sma_history]
    slow_sma_history = [slow_sma | state.slow_sma_history]

    cond do
      # Fast SMA crosses above slow SMA - buy signal
      crossover?(fast_sma_history, slow_sma_history) and current_position != :long ->
        if current_position == :short do
          close_sell()
        end

        buy()

      # Fast SMA crosses below slow SMA - sell signal  
      crossover?(slow_sma_history, fast_sma_history) and current_position != :short ->
        if current_position == :long do
          close_buy()
        end

        sell()

      true ->
        # No action
        :ok
    end
  end
end
