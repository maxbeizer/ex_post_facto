defmodule ExPostFacto.ExampleStrategies.BreakoutStrategy do
  @moduledoc """
  Price breakout strategy based on support and resistance levels.

  This strategy identifies breakouts from trading ranges:
  - Buy when price breaks above recent high (resistance)
  - Sell when price breaks below recent low (support)
  - Uses volume confirmation when available
  - Includes trailing stop loss functionality

  ## Parameters

  - `:lookback_period` - Period for identifying highs/lows (default: 20)
  - `:breakout_threshold` - Percentage above/below high/low for breakout (default: 0.02 = 2%)
  - `:volume_confirmation` - Require volume confirmation for breakouts (default: false)
  - `:volume_multiplier` - Volume must be X times average (default: 1.5)
  - `:trailing_stop_pct` - Trailing stop loss percentage (default: 0.03 = 3%)

  ## Example

      {:ok, result} = ExPostFacto.backtest(
        market_data,
        {ExPostFacto.ExampleStrategies.BreakoutStrategy, [
          lookback_period: 15,
          breakout_threshold: 0.025,
          volume_confirmation: true
        ]}
      )
  """

  use ExPostFacto.Strategy

  def init(opts) do
    lookback_period = Keyword.get(opts, :lookback_period, 20)
    breakout_threshold = Keyword.get(opts, :breakout_threshold, 0.02)
    volume_confirmation = Keyword.get(opts, :volume_confirmation, false)
    volume_multiplier = Keyword.get(opts, :volume_multiplier, 1.5)
    trailing_stop_pct = Keyword.get(opts, :trailing_stop_pct, 0.03)

    if lookback_period <= 0 do
      {:error, "lookback_period must be positive"}
    else
      {:ok,
       %{
         lookback_period: lookback_period,
         breakout_threshold: breakout_threshold,
         volume_confirmation: volume_confirmation,
         volume_multiplier: volume_multiplier,
         trailing_stop_pct: trailing_stop_pct,
         price_history: [],
         volume_history: [],
         high_history: [],
         low_history: [],
         entry_price: nil,
         trailing_stop: nil
       }}
    end
  end

  def next(state) do
    current_data = data()
    current_price = current_data.close
    current_high = Map.get(current_data, :high, current_price)
    current_low = Map.get(current_data, :low, current_price)
    current_volume = Map.get(current_data, :volume, 0)

    updated_state = %{
      state
      | price_history: [current_price | state.price_history],
        volume_history: [current_volume | state.volume_history],
        high_history: [current_high | state.high_history],
        low_history: [current_low | state.low_history]
    }

    # Only trade if we have sufficient history
    final_state =
      if length(updated_state.price_history) >= state.lookback_period do
        # Update trailing stop
        updated_with_stop = update_trailing_stop(current_price, updated_state)

        # Check for exit conditions first
        checked_exit = check_exit_conditions(current_price, updated_with_stop)

        # Then check for entry conditions
        check_entry_conditions(current_price, current_volume, checked_exit)
      else
        updated_state
      end

    {:ok, final_state}
  end

  # Private helper functions

  defp update_trailing_stop(current_price, state) do
    current_position = position()

    case {current_position, state.entry_price, state.trailing_stop} do
      {:long, entry_price, nil} when not is_nil(entry_price) ->
        # Initialize trailing stop
        initial_stop = entry_price * (1 - state.trailing_stop_pct)
        %{state | trailing_stop: initial_stop}

      {:long, _entry_price, trailing_stop} when not is_nil(trailing_stop) ->
        # Update trailing stop (only move up for long positions)
        new_stop = current_price * (1 - state.trailing_stop_pct)
        updated_stop = max(trailing_stop, new_stop)
        %{state | trailing_stop: updated_stop}

      {:short, entry_price, nil} when not is_nil(entry_price) ->
        # Initialize trailing stop for short
        initial_stop = entry_price * (1 + state.trailing_stop_pct)
        %{state | trailing_stop: initial_stop}

      {:short, _entry_price, trailing_stop} when not is_nil(trailing_stop) ->
        # Update trailing stop (only move down for short positions)
        new_stop = current_price * (1 + state.trailing_stop_pct)
        updated_stop = min(trailing_stop, new_stop)
        %{state | trailing_stop: updated_stop}

      _ ->
        state
    end
  end

  defp check_exit_conditions(current_price, state) do
    current_position = position()

    case {current_position, state.trailing_stop} do
      {:long, trailing_stop} when not is_nil(trailing_stop) ->
        if current_price <= trailing_stop do
          close_buy()
          %{state | entry_price: nil, trailing_stop: nil}
        else
          state
        end

      {:short, trailing_stop} when not is_nil(trailing_stop) ->
        if current_price >= trailing_stop do
          close_sell()
          %{state | entry_price: nil, trailing_stop: nil}
        else
          state
        end

      _ ->
        state
    end
  end

  defp check_entry_conditions(current_price, current_volume, state) do
    current_position = position()

    # Calculate support and resistance levels
    recent_highs = Enum.take(state.high_history, state.lookback_period)
    recent_lows = Enum.take(state.low_history, state.lookback_period)

    resistance_level = Enum.max(recent_highs)
    support_level = Enum.min(recent_lows)

    # Calculate breakout thresholds
    upward_breakout = resistance_level * (1 + state.breakout_threshold)
    downward_breakout = support_level * (1 - state.breakout_threshold)

    # Check volume confirmation if required
    volume_confirmed = check_volume_confirmation(current_volume, state)

    cond do
      # Upward breakout - buy signal
      current_price > upward_breakout and current_position != :long and
          (!state.volume_confirmation or volume_confirmed) ->
        if current_position == :short, do: close_sell()
        buy()
        %{state | entry_price: current_price, trailing_stop: nil}

      # Downward breakout - sell signal
      current_price < downward_breakout and current_position != :short and
          (!state.volume_confirmation or volume_confirmed) ->
        if current_position == :long, do: close_buy()
        sell()
        %{state | entry_price: current_price, trailing_stop: nil}

      true ->
        state
    end
  end

  defp check_volume_confirmation(current_volume, state) do
    if state.volume_confirmation and length(state.volume_history) >= state.lookback_period do
      recent_volumes = Enum.take(state.volume_history, state.lookback_period)
      average_volume = Enum.sum(recent_volumes) / length(recent_volumes)
      current_volume >= average_volume * state.volume_multiplier
    else
      true
    end
  end
end