defmodule ExPostFacto.Strategy do
  @moduledoc """
  A behaviour for implementing trading strategies with enhanced features.

  This module provides a more intuitive API for strategy development compared to
  the traditional MFA tuple approach. Strategies implement the `init/1` and
  `next/1` callbacks and have access to built-in position management, equity
  tracking, and indicator helpers.

  ## Example Strategy

      defmodule MyStrategy do
        use ExPostFacto.Strategy

        def init(_opts) do
          sma_fast = indicator(&calculate_sma/2, data().close, 10)
          sma_slow = indicator(&calculate_sma/2, data().close, 20)
          {:ok, %{sma_fast: sma_fast, sma_slow: sma_slow}}
        end

        def next(state) do
          if crossover?(state.sma_fast, state.sma_slow) do
            buy()
          end
          {:ok, state}
        end
      end

  ## Callbacks

  - `init/1` - Called once to initialize strategy state
  - `next/1` - Called for each data point with strategy state

  ## Helper Functions

  When using this behaviour, the following helper functions are available:

  - `buy/0`, `sell/0` - Enter long/short positions
  - `close_buy/0`, `close_sell/0` - Close long/short positions  
  - `crossover?/2` - Check if one series crosses above another
  - `data/0` - Access current market data point
  - `equity/0` - Get current account equity
  - `position/0` - Get current position state
  - `indicator/3` - Create technical indicators
  """

  alias ExPostFacto.StrategyContext

  @doc """
  Initialize the strategy with given options.

  Returns `{:ok, state}` where state is the initial strategy state,
  or `{:error, reason}` if initialization fails.
  """
  @callback init(opts :: keyword()) :: {:ok, state :: any()} | {:error, reason :: any()}

  @doc """
  Process the next data point.

  Called for each data point with the current strategy state.
  Returns `{:ok, new_state}` or `{:error, reason}`.

  Actions are triggered by calling helper functions like `buy()`, `sell()`, etc.
  within this callback.
  """
  @callback next(state :: any()) :: {:ok, new_state :: any()} | {:error, reason :: any()}

  defmacro __using__(_opts) do
    quote do
      @behaviour ExPostFacto.Strategy

      import ExPostFacto.Strategy,
        only: [
          buy: 0,
          sell: 0,
          close_buy: 0,
          close_sell: 0,
          crossover?: 2,
          data: 0,
          equity: 0,
          position: 0
        ]

      # Default implementations
      def init(_opts), do: {:ok, %{}}
      def next(state), do: {:ok, state}

      defoverridable init: 1, next: 1
    end
  end

  @doc """
  Enter a long position (buy).
  """
  def buy do
    StrategyContext.set_action(:buy)
  end

  @doc """
  Enter a short position (sell).
  """
  def sell do
    StrategyContext.set_action(:sell)
  end

  @doc """
  Close a long position.
  """
  def close_buy do
    StrategyContext.set_action(:close_buy)
  end

  @doc """
  Close a short position.
  """
  def close_sell do
    StrategyContext.set_action(:close_sell)
  end

  @doc """
  Check if the first series crosses above the second series.

  Returns true if there was a crossover on the current data point.
  Delegates to ExPostFacto.Indicators for comprehensive crossover detection.
  """
  def crossover?(series1, series2) when is_list(series1) and is_list(series2) do
    ExPostFacto.Indicators.crossover?(series1, series2)
  end

  def crossover?(val1, val2) when is_number(val1) and is_number(val2) do
    # For single values, we can't determine crossover without history
    # This would need to be enhanced with historical data tracking
    false
  end

  @doc """
  Check if the first series crosses below the second series.

  Returns true if there was a crossunder on the current data point.
  """
  def crossunder?(series1, series2) when is_list(series1) and is_list(series2) do
    ExPostFacto.Indicators.crossunder?(series1, series2)
  end

  @doc """
  Get the current market data point.
  """
  def data do
    StrategyContext.get_data()
  end

  @doc """
  Get the current account equity.
  """
  def equity do
    StrategyContext.get_equity()
  end

  @doc """
  Get the current position state.
  """
  def position do
    StrategyContext.get_position()
  end

  @doc """
  Create a technical indicator using the ExPostFacto.Indicators module.

  This function provides a convenient interface for calculating technical indicators
  within strategies. It delegates to the comprehensive indicator framework.

  ## Parameters

  - `indicator_type` - Atom representing the indicator type (:sma, :ema, :rsi, etc.)
  - `data` - List or stream of numeric values
  - `params` - Parameters for the indicator (period, etc.)

  ## Examples

      # Simple Moving Average
      sma_values = indicator(:sma, price_data, 20)

      # Exponential Moving Average  
      ema_values = indicator(:ema, price_data, 12)

      # RSI
      rsi_values = indicator(:rsi, price_data, 14)

      # MACD (returns tuple)
      {macd, signal, histogram} = indicator(:macd, price_data, {12, 26, 9})

      # Bollinger Bands (returns tuple)
      {upper, middle, lower} = indicator(:bollinger_bands, price_data, {20, 2})

  """
  def indicator(indicator_type, data, params \\ nil)

  def indicator(:sma, data, period) when is_integer(period) do
    ExPostFacto.Indicators.sma(data, period)
  end

  def indicator(:ema, data, period) when is_integer(period) do
    ExPostFacto.Indicators.ema(data, period)
  end

  def indicator(:rsi, data, period) when is_integer(period) do
    ExPostFacto.Indicators.rsi(data, period)
  end

  def indicator(:rsi, data, nil) do
    ExPostFacto.Indicators.rsi(data, 14)
  end

  def indicator(:macd, data, {fast, slow, signal}) do
    ExPostFacto.Indicators.macd(data, fast, slow, signal)
  end

  def indicator(:macd, data, nil) do
    ExPostFacto.Indicators.macd(data)
  end

  def indicator(:bollinger_bands, data, {period, std_dev}) do
    ExPostFacto.Indicators.bollinger_bands(data, period, std_dev)
  end

  def indicator(:bollinger_bands, data, nil) do
    ExPostFacto.Indicators.bollinger_bands(data)
  end

  def indicator(:atr, data, period) when is_integer(period) do
    ExPostFacto.Indicators.atr(data, period)
  end

  def indicator(:atr, data, nil) do
    ExPostFacto.Indicators.atr(data)
  end

  # Legacy function support for backward compatibility
  def indicator(func, data, period)
      when is_function(func) and is_list(data) and is_integer(period) do
    # Simplified indicator calculation for backward compatibility
    if length(data) >= period do
      data
      |> Enum.take(period)
      |> Enum.sum()
      |> Kernel./(period)
    else
      0.0
    end
  end
end
