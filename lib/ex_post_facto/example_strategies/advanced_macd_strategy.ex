defmodule ExPostFacto.ExampleStrategies.AdvancedMacdStrategy do
  @moduledoc """
  Advanced strategy demonstrating the indicator framework capabilities.

  This strategy uses multiple indicators:
  - MACD for trend direction and momentum
  - RSI for overbought/oversold conditions
  - Bollinger Bands for volatility and mean reversion
  - SMA for additional trend confirmation

  ## Trading Rules

  **Buy Signals:**
  - MACD line crosses above signal line (bullish momentum)
  - RSI is below 70 (not overbought)
  - Price is near or below lower Bollinger Band (oversold)

  **Sell Signals:**
  - MACD line crosses below signal line (bearish momentum)
  - RSI is above 30 (not oversold)
  - Price is near or above upper Bollinger Band (overbought)

  This demonstrates advanced indicator usage, chaining, and composition.
  """

  use ExPostFacto.Strategy

  @doc """
  Initialize the strategy with indicator parameters.

  Options:
  - `:macd_fast` - MACD fast period (default: 12)
  - `:macd_slow` - MACD slow period (default: 26)  
  - `:macd_signal` - MACD signal period (default: 9)
  - `:rsi_period` - RSI period (default: 14)
  - `:bb_period` - Bollinger Bands period (default: 20)
  - `:bb_std_dev` - Bollinger Bands standard deviation (default: 2.0)
  - `:sma_period` - SMA period for trend confirmation (default: 50)
  """
  def init(opts) do
    config = %{
      macd_fast: Keyword.get(opts, :macd_fast, 12),
      macd_slow: Keyword.get(opts, :macd_slow, 26),
      macd_signal: Keyword.get(opts, :macd_signal, 9),
      rsi_period: Keyword.get(opts, :rsi_period, 14),
      bb_period: Keyword.get(opts, :bb_period, 20),
      bb_std_dev: Keyword.get(opts, :bb_std_dev, 2.0),
      sma_period: Keyword.get(opts, :sma_period, 50),
      price_history: [],
      macd_history: [],
      signal_history: [],
      position_entered_at: nil
    }

    {:ok, config}
  end

  @doc """
  Process each data point using multiple indicators for trading decisions.
  """
  def next(state) do
    current_data = data()
    current_price = Map.get(current_data, :close, 0.0)

    # Update price history
    updated_price_history = [current_price | state.price_history]
    max_needed = Enum.max([state.macd_slow, state.bb_period, state.sma_period]) + 10

    # Keep only necessary history for performance
    trimmed_price_history = Enum.take(updated_price_history, max_needed)

    # Calculate all indicators
    indicators = calculate_indicators(trimmed_price_history, state)

    # Make trading decision
    make_trading_decision(indicators, state, current_price)

    # Update state
    new_state = %{
      state
      | price_history: trimmed_price_history,
        macd_history: [indicators.macd | state.macd_history] |> Enum.take(5),
        signal_history: [indicators.signal | state.signal_history] |> Enum.take(5)
    }

    {:ok, new_state}
  end

  # Private helper functions

  defp calculate_indicators(price_history, config) do
    # Calculate MACD
    {macd_line, signal_line, _histogram} =
      indicator(:macd, price_history, {config.macd_fast, config.macd_slow, config.macd_signal})

    # Calculate RSI
    rsi_values = indicator(:rsi, price_history, config.rsi_period)

    # Calculate Bollinger Bands
    {bb_upper, bb_middle, bb_lower} =
      indicator(:bollinger_bands, price_history, {config.bb_period, config.bb_std_dev})

    # Calculate SMA for trend confirmation
    sma_values = indicator(:sma, price_history, config.sma_period)

    # Get current values (most recent)
    %{
      macd: List.first(macd_line),
      signal: List.first(signal_line),
      rsi: List.first(rsi_values),
      bb_upper: List.first(bb_upper),
      bb_middle: List.first(bb_middle),
      bb_lower: List.first(bb_lower),
      sma: List.first(sma_values),
      # Keep series for crossover detection
      macd_series: macd_line,
      signal_series: signal_line
    }
  end

  defp make_trading_decision(indicators, _state, current_price) do
    current_position = position()

    cond do
      should_buy?(indicators, current_price) and current_position != :long ->
        if current_position == :short do
          close_sell()
        end

        buy()

      should_sell?(indicators, current_price) and current_position != :short ->
        if current_position == :long do
          close_buy()
        end

        sell()

      true ->
        :no_action
    end
  end

  defp should_buy?(indicators, current_price) do
    with true <- not is_nil(indicators.macd),
         true <- not is_nil(indicators.signal),
         true <- not is_nil(indicators.rsi),
         true <- not is_nil(indicators.bb_lower),
         true <- not is_nil(indicators.sma) do
      # MACD bullish crossover
      macd_bullish = crossover?(indicators.macd_series, indicators.signal_series)

      # RSI not overbought
      rsi_ok = indicators.rsi < 70

      # Price near lower Bollinger Band (oversold condition)
      oversold = current_price <= indicators.bb_lower * 1.02

      # Above long-term SMA (uptrend)
      uptrend = current_price > indicators.sma

      macd_bullish and rsi_ok and (oversold or uptrend)
    else
      _ -> false
    end
  end

  defp should_sell?(indicators, current_price) do
    with true <- not is_nil(indicators.macd),
         true <- not is_nil(indicators.signal),
         true <- not is_nil(indicators.rsi),
         true <- not is_nil(indicators.bb_upper),
         true <- not is_nil(indicators.sma) do
      # MACD bearish crossover
      macd_bearish = crossunder?(indicators.macd_series, indicators.signal_series)

      # RSI not oversold
      rsi_ok = indicators.rsi > 30

      # Price near upper Bollinger Band (overbought condition)
      overbought = current_price >= indicators.bb_upper * 0.98

      # Below long-term SMA (downtrend)
      downtrend = current_price < indicators.sma

      macd_bearish and rsi_ok and (overbought or downtrend)
    else
      _ -> false
    end
  end
end
