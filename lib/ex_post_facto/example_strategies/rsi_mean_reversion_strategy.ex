defmodule ExPostFacto.ExampleStrategies.RSIMeanReversionStrategy do
  @moduledoc """
  RSI-based mean reversion strategy.

  This strategy uses the Relative Strength Index (RSI) to identify overbought and oversold conditions:
  - Buy when RSI falls below oversold threshold (typically 30)
  - Sell when RSI rises above overbought threshold (typically 70)
  - Includes stop-loss and take-profit mechanisms

  ## Parameters

  - `:rsi_period` - Period for RSI calculation (default: 14)
  - `:oversold_threshold` - RSI level considered oversold (default: 30)
  - `:overbought_threshold` - RSI level considered overbought (default: 70)
  - `:stop_loss_pct` - Stop loss as percentage of entry price (default: 0.05 = 5%)
  - `:take_profit_pct` - Take profit as percentage of entry price (default: 0.10 = 10%)

  ## Example

      {:ok, result} = ExPostFacto.backtest(
        market_data,
        {ExPostFacto.ExampleStrategies.RSIMeanReversionStrategy, [
          rsi_period: 14,
          oversold_threshold: 25,
          overbought_threshold: 75
        ]}
      )
  """

  use ExPostFacto.Strategy

  def init(opts) do
    rsi_period = Keyword.get(opts, :rsi_period, 14)
    oversold_threshold = Keyword.get(opts, :oversold_threshold, 30)
    overbought_threshold = Keyword.get(opts, :overbought_threshold, 70)
    stop_loss_pct = Keyword.get(opts, :stop_loss_pct, 0.05)
    take_profit_pct = Keyword.get(opts, :take_profit_pct, 0.10)

    cond do
      rsi_period <= 0 ->
        {:error, "rsi_period must be positive"}

      oversold_threshold >= overbought_threshold ->
        {:error, "oversold_threshold must be less than overbought_threshold"}

      stop_loss_pct <= 0 or take_profit_pct <= 0 ->
        {:error, "stop_loss_pct and take_profit_pct must be positive"}

      true ->
        {:ok,
         %{
           rsi_period: rsi_period,
           oversold_threshold: oversold_threshold,
           overbought_threshold: overbought_threshold,
           stop_loss_pct: stop_loss_pct,
           take_profit_pct: take_profit_pct,
           price_history: [],
           entry_price: nil,
           entry_type: nil
         }}
    end
  end

  def next(state) do
    current_price = data().close
    updated_history = [current_price | state.price_history]

    # Calculate RSI if we have enough data
    new_state =
      if length(updated_history) >= state.rsi_period + 1 do
        rsi_values = indicator(:rsi, updated_history, state.rsi_period)
        current_rsi = List.first(rsi_values)

        # Check for exit conditions first
        updated_state = check_exit_conditions(current_price, state)

        # Then check for entry conditions
        check_entry_conditions(current_rsi, current_price, updated_state)
      else
        state
      end

    {:ok, %{new_state | price_history: updated_history}}
  end

  # Private helper functions

  defp check_exit_conditions(current_price, state) do
    current_position = position()

    case {current_position, state.entry_price, state.entry_type} do
      {:long, entry_price, :long} when not is_nil(entry_price) ->
        check_long_exit(current_price, entry_price, state)

      {:short, entry_price, :short} when not is_nil(entry_price) ->
        check_short_exit(current_price, entry_price, state)

      _ ->
        state
    end
  end

  defp check_long_exit(current_price, entry_price, state) do
    loss_pct = (entry_price - current_price) / entry_price
    profit_pct = (current_price - entry_price) / entry_price

    cond do
      loss_pct >= state.stop_loss_pct ->
        close_buy()
        %{state | entry_price: nil, entry_type: nil}

      profit_pct >= state.take_profit_pct ->
        close_buy()
        %{state | entry_price: nil, entry_type: nil}

      true ->
        state
    end
  end

  defp check_short_exit(current_price, entry_price, state) do
    loss_pct = (current_price - entry_price) / entry_price
    profit_pct = (entry_price - current_price) / entry_price

    cond do
      loss_pct >= state.stop_loss_pct ->
        close_sell()
        %{state | entry_price: nil, entry_type: nil}

      profit_pct >= state.take_profit_pct ->
        close_sell()
        %{state | entry_price: nil, entry_type: nil}

      true ->
        state
    end
  end

  defp check_entry_conditions(current_rsi, current_price, state) do
    current_position = position()

    cond do
      # RSI oversold - potential buy signal
      current_rsi < state.oversold_threshold and current_position != :long ->
        if current_position == :short, do: close_sell()
        buy()
        %{state | entry_price: current_price, entry_type: :long}

      # RSI overbought - potential sell signal
      current_rsi > state.overbought_threshold and current_position != :short ->
        if current_position == :long, do: close_buy()
        sell()
        %{state | entry_price: current_price, entry_type: :short}

      true ->
        state
    end
  end
end
