defmodule ExPostFacto.ExampleStrategies.MultiIndicatorStrategy do
  @moduledoc """
  Advanced multi-indicator strategy combining multiple signals.

  This strategy demonstrates how to combine multiple technical indicators for
  more robust trading decisions:
  - RSI for momentum (oversold/overbought conditions)
  - MACD for trend direction (crossovers)
  - Bollinger Bands for volatility-based entries
  - SMA for overall trend filter

  Signal Logic:
  - Buy when: RSI < oversold AND MACD bullish crossover AND price near lower BB AND above long-term SMA
  - Sell when: RSI > overbought AND MACD bearish crossover AND price near upper BB AND below long-term SMA
  - Use stop-loss and take-profit for risk management

  ## Parameters

  - `:rsi_period` - RSI calculation period (default: 14)
  - `:rsi_oversold` - RSI oversold threshold (default: 30)
  - `:rsi_overbought` - RSI overbought threshold (default: 70)
  - `:macd_fast` - MACD fast EMA period (default: 12)
  - `:macd_slow` - MACD slow EMA period (default: 26)
  - `:macd_signal` - MACD signal line period (default: 9)
  - `:bb_period` - Bollinger Bands period (default: 20)
  - `:bb_std_dev` - Bollinger Bands standard deviations (default: 2.0)
  - `:sma_trend_period` - Long-term SMA for trend filter (default: 50)
  - `:stop_loss_pct` - Stop loss percentage (default: 0.03)
  - `:take_profit_pct` - Take profit percentage (default: 0.06)

  ## Example

      {:ok, result} = ExPostFacto.backtest(
        market_data,
        {ExPostFacto.ExampleStrategies.MultiIndicatorStrategy, [
          rsi_period: 14,
          rsi_oversold: 25,
          rsi_overbought: 75,
          stop_loss_pct: 0.02
        ]}
      )
  """

  use ExPostFacto.Strategy

  def init(opts) do
    # RSI parameters
    rsi_period = Keyword.get(opts, :rsi_period, 14)
    rsi_oversold = Keyword.get(opts, :rsi_oversold, 30)
    rsi_overbought = Keyword.get(opts, :rsi_overbought, 70)

    # MACD parameters
    macd_fast = Keyword.get(opts, :macd_fast, 12)
    macd_slow = Keyword.get(opts, :macd_slow, 26)
    macd_signal = Keyword.get(opts, :macd_signal, 9)

    # Bollinger Bands parameters
    bb_period = Keyword.get(opts, :bb_period, 20)
    bb_std_dev = Keyword.get(opts, :bb_std_dev, 2.0)

    # Trend filter
    sma_trend_period = Keyword.get(opts, :sma_trend_period, 50)

    # Risk management
    stop_loss_pct = Keyword.get(opts, :stop_loss_pct, 0.03)
    take_profit_pct = Keyword.get(opts, :take_profit_pct, 0.06)

    # Validation
    min_required = max(max(rsi_period, macd_slow + macd_signal), max(bb_period, sma_trend_period))

    {:ok,
     %{
       # Indicator parameters
       rsi_period: rsi_period,
       rsi_oversold: rsi_oversold,
       rsi_overbought: rsi_overbought,
       macd_fast: macd_fast,
       macd_slow: macd_slow,
       macd_signal: macd_signal,
       bb_period: bb_period,
       bb_std_dev: bb_std_dev,
       sma_trend_period: sma_trend_period,

       # Risk management
       stop_loss_pct: stop_loss_pct,
       take_profit_pct: take_profit_pct,

       # State tracking
       price_history: [],
       macd_history: [],
       signal_history: [],
       entry_price: nil,
       entry_type: nil,
       min_required: min_required
     }}
  end

  def next(state) do
    current_price = data().close
    updated_history = [current_price | state.price_history]

    # Only trade when we have sufficient history
    new_state =
      if length(updated_history) >= state.min_required do
        # Check exit conditions first (stop loss / take profit)
        state_after_exit = check_exit_conditions(current_price, state)

        # Then check entry conditions if not in position
        check_entry_conditions(current_price, updated_history, state_after_exit)
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

  defp check_entry_conditions(current_price, price_history, state) do
    current_position = position()

    # Only look for entries if not in a position
    if current_position == :none do
      # Calculate all indicators
      indicators = calculate_indicators(price_history, state)

      # Check for bullish signal
      cond do
        bullish_signal?(current_price, indicators, state) ->
          buy()
          %{state | entry_price: current_price, entry_type: :long}
        
        bearish_signal?(current_price, indicators, state) ->
          sell()
          %{state | entry_price: current_price, entry_type: :short}
        
        true ->
          state
      end
    else
      state
    end
  end

  defp calculate_indicators(price_history, state) do
    # RSI
    rsi_values = indicator(:rsi, price_history, state.rsi_period)
    current_rsi = List.first(rsi_values)

    # MACD
    {macd_line, signal_line, _histogram} =
      indicator(:macd, price_history, {state.macd_fast, state.macd_slow, state.macd_signal})

    current_macd = List.first(macd_line)
    current_signal = List.first(signal_line)

    # Update MACD history for crossover detection
    updated_macd_history = [current_macd | state.macd_history]
    updated_signal_history = [current_signal | state.signal_history]

    # Bollinger Bands
    {bb_upper, bb_middle, bb_lower} =
      indicator(:bollinger_bands, price_history, {state.bb_period, state.bb_std_dev})

    # Trend filter SMA
    sma_trend = indicator(:sma, price_history, state.sma_trend_period) |> List.first()

    %{
      rsi: current_rsi,
      macd: current_macd,
      signal: current_signal,
      macd_history: updated_macd_history,
      signal_history: updated_signal_history,
      bb_upper: bb_upper,
      bb_middle: bb_middle,
      bb_lower: bb_lower,
      sma_trend: sma_trend
    }
  end

  defp bullish_signal?(current_price, indicators, state) do
    # RSI oversold
    rsi_condition = indicators.rsi < state.rsi_oversold

    # MACD bullish crossover (if we have enough history)
    macd_condition =
      if length(indicators.macd_history) >= 2 do
        crossover?(indicators.macd_history, indicators.signal_history)
      else
        indicators.macd > indicators.signal
      end

    # Price near lower Bollinger Band (within 2% of lower band)
    bb_condition = current_price <= indicators.bb_lower * 1.02

    # Above long-term trend (bullish bias)
    trend_condition = current_price > indicators.sma_trend

    # All conditions must be true
    rsi_condition and macd_condition and bb_condition and trend_condition
  end

  defp bearish_signal?(current_price, indicators, state) do
    # RSI overbought
    rsi_condition = indicators.rsi > state.rsi_overbought

    # MACD bearish crossover (if we have enough history)
    macd_condition =
      if length(indicators.macd_history) >= 2 do
        crossover?(indicators.signal_history, indicators.macd_history)
      else
        indicators.macd < indicators.signal
      end

    # Price near upper Bollinger Band (within 2% of upper band)
    bb_condition = current_price >= indicators.bb_upper * 0.98

    # Below long-term trend (bearish bias)
    trend_condition = current_price < indicators.sma_trend

    # All conditions must be true
    rsi_condition and macd_condition and bb_condition and trend_condition
  end
end
