defmodule ExPostFacto.ExampleStrategies.BollingerBandStrategy do
  @moduledoc """
  Bollinger Band mean reversion strategy.

  This strategy uses Bollinger Bands to identify overbought and oversold conditions:
  - Buy when price touches the lower band (oversold)
  - Sell when price touches the upper band (overbought)
  - Close positions when price returns to the middle band

  ## Parameters

  - `:period` - Period for moving average and bands calculation (default: 20)
  - `:std_dev` - Number of standard deviations for bands (default: 2.0)
  - `:min_history` - Minimum price history required (default: 25)

  ## Example

      # Run with default parameters
      {:ok, result} = ExPostFacto.backtest(
        market_data,
        {ExPostFacto.ExampleStrategies.BollingerBandStrategy, []}
      )

      # Run with custom parameters
      {:ok, result} = ExPostFacto.backtest(
        market_data,
        {ExPostFacto.ExampleStrategies.BollingerBandStrategy, [
          period: 15,
          std_dev: 2.5
        ]}
      )
  """

  use ExPostFacto.Strategy

  def init(opts) do
    period = Keyword.get(opts, :period, 20)
    std_dev = Keyword.get(opts, :std_dev, 2.0)
    min_history = Keyword.get(opts, :min_history, 25)

    if period <= 0 do
      {:error, "period must be positive"}
    else
      {:ok,
       %{
         period: period,
         std_dev: std_dev,
         min_history: min_history,
         price_history: [],
         last_signal: nil
       }}
    end
  end

  def next(state) do
    current_price = data().close
    updated_history = [current_price | state.price_history]

    # Only trade if we have sufficient history
    if length(updated_history) >= state.min_history do
      {upper_band, middle_band, lower_band} =
        indicator(:bollinger_bands, updated_history, {state.period, state.std_dev})

      make_trading_decision(current_price, upper_band, middle_band, lower_band, state)
    end

    {:ok, %{state | price_history: updated_history}}
  end

  # Private helper functions

  defp make_trading_decision(current_price, upper_band, middle_band, lower_band, state) do
    current_position = position()

    cond do
      # Price touches lower band - oversold, buy signal
      current_price <= lower_band and current_position != :long ->
        if current_position == :short, do: close_sell()
        buy()
        update_signal(:buy)

      # Price touches upper band - overbought, sell signal
      current_price >= upper_band and current_position != :short ->
        if current_position == :long, do: close_buy()
        sell()
        update_signal(:sell)

      # Price returns to middle band - close positions
      price_near_middle?(current_price, middle_band) ->
        case current_position do
          :long -> close_buy()
          :short -> close_sell()
          _ -> :ok
        end

        update_signal(:close)

      true ->
        :ok
    end
  end

  defp price_near_middle?(price, middle_band, tolerance \\ 0.005) do
    abs(price - middle_band) / middle_band <= tolerance
  end

  defp update_signal(signal) do
    # This would be useful for debugging/analysis
    # For now, we just track the last signal
    signal
  end
end
