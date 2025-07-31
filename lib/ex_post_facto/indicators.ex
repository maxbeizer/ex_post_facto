defmodule ExPostFacto.Indicators do
  @moduledoc """
  Technical indicators for trading strategy development.

  This module provides a comprehensive set of technical indicators commonly used
  in trading strategies. All indicators are designed to work efficiently with
  streaming data and support composition and chaining.

  ## Supported Indicators

  - **SMA** - Simple Moving Average
  - **EMA** - Exponential Moving Average  
  - **RSI** - Relative Strength Index
  - **MACD** - Moving Average Convergence Divergence
  - **Bollinger Bands** - Bollinger Bands with configurable standard deviations
  - **ATR** - Average True Range

  ## Example Usage

      # Simple Moving Average
      prices = [10, 11, 12, 13, 14, 15]
      sma_values = ExPostFacto.Indicators.sma(prices, 3)

      # Exponential Moving Average
      ema_values = ExPostFacto.Indicators.ema(prices, 3)

      # RSI
      rsi_values = ExPostFacto.Indicators.rsi(prices, 14)

      # Crossover detection
      fast_ma = ExPostFacto.Indicators.sma(prices, 5)
      slow_ma = ExPostFacto.Indicators.sma(prices, 10)
      crossover = ExPostFacto.Indicators.crossover?(fast_ma, slow_ma)

  ## Stream Support

  All indicators work with Elixir streams for memory-efficient processing:

      large_dataset
      |> Stream.map(&(&1.close))
      |> ExPostFacto.Indicators.sma(20)
      |> Enum.to_list()
  """

  @doc """
  Calculate Simple Moving Average (SMA).

  Returns a list of SMA values. For periods where insufficient data is available,
  returns nil values.

  ## Parameters

  - `data` - List or Stream of numeric values
  - `period` - Number of periods for the moving average

  ## Examples

      iex> ExPostFacto.Indicators.sma([1, 2, 3, 4, 5], 3)
      [nil, nil, 2.0, 3.0, 4.0]

      iex> ExPostFacto.Indicators.sma([10, 20, 30], 2)
      [nil, 15.0, 25.0]
  """
  @spec sma(Enumerable.t(), pos_integer()) :: [float() | nil]
  def sma(data, period) when is_integer(period) and period > 0 do
    data
    |> Stream.with_index()
    |> Stream.map(fn {_value, index} ->
      if index + 1 >= period do
        period_data =
          data
          |> Enum.take(index + 1)
          |> Enum.take(-period)
          |> Enum.filter(&(&1 != nil))

        if length(period_data) == period do
          Enum.sum(period_data) / period
        else
          nil
        end
      else
        nil
      end
    end)
    |> Enum.to_list()
  end

  @doc """
  Calculate Exponential Moving Average (EMA).

  The EMA gives more weight to recent prices and responds more quickly to price changes
  than a simple moving average.

  ## Parameters

  - `data` - List or Stream of numeric values
  - `period` - Number of periods for the EMA calculation

  ## Examples

      iex> prices = [22.27, 22.19, 22.08, 22.17, 22.18, 22.13, 22.23, 22.43, 22.24, 22.29]
      iex> ema_values = ExPostFacto.Indicators.ema(prices, 10)
      iex> List.last(ema_values) |> Float.round(4)
      22.2210
  """
  @spec ema(Enumerable.t(), pos_integer()) :: [float() | nil]
  def ema(data, period) when is_integer(period) and period > 0 do
    multiplier = 2.0 / (period + 1)

    data
    |> Enum.to_list()
    |> ema_recursive(period, multiplier, [])
    |> Enum.reverse()
  end

  # Private helper for EMA calculation
  defp ema_recursive([], _period, _multiplier, acc), do: acc

  defp ema_recursive([price | rest], period, multiplier, []) do
    # First value uses SMA
    if length([price | rest]) >= period do
      first_values = Enum.take([price | rest], period)
      first_ema = Enum.sum(first_values) / period
      remaining = Enum.drop([price | rest], period)
      ema_recursive(remaining, period, multiplier, [first_ema | List.duplicate(nil, period - 1)])
    else
      ema_recursive(rest, period, multiplier, [nil])
    end
  end

  defp ema_recursive([price | rest], period, multiplier, [prev_ema | _] = acc)
       when is_float(prev_ema) do
    new_ema = price * multiplier + prev_ema * (1 - multiplier)
    ema_recursive(rest, period, multiplier, [new_ema | acc])
  end

  defp ema_recursive([_price | rest], period, multiplier, acc) do
    ema_recursive(rest, period, multiplier, [nil | acc])
  end

  @doc """
  Calculate Relative Strength Index (RSI).

  RSI is a momentum oscillator that measures the speed and magnitude of price changes.
  Values range from 0 to 100.

  ## Parameters

  - `data` - List or Stream of numeric values (typically closing prices)
  - `period` - Number of periods for RSI calculation (default: 14)

  ## Examples

      iex> prices = [44, 44.34, 44.09, 44.15, 43.61, 44.33, 44.83, 45.85, 46.08, 45.89, 46.03, 46.83, 47.69, 46.49, 46.26]
      iex> rsi_values = ExPostFacto.Indicators.rsi(prices, 14)
      iex> List.last(rsi_values) |> Float.round(2)
      70.53
  """
  @spec rsi(Enumerable.t(), pos_integer()) :: [float() | nil]
  def rsi(data, period \\ 14) when is_integer(period) and period > 0 do
    data
    |> Enum.to_list()
    |> calculate_price_changes()
    |> calculate_rsi_values(period)
  end

  # Calculate price changes (gains and losses)
  defp calculate_price_changes([]), do: []
  defp calculate_price_changes([_first]), do: [nil]

  defp calculate_price_changes([first, second | rest]) do
    change = second - first
    [nil | calculate_price_changes_recursive([second | rest], [change])]
  end

  defp calculate_price_changes_recursive([_last], acc), do: Enum.reverse(acc)

  defp calculate_price_changes_recursive([current, next | rest], acc) do
    change = next - current
    calculate_price_changes_recursive([next | rest], [change | acc])
  end

  # Calculate RSI from price changes
  defp calculate_rsi_values(changes, period) do
    changes
    |> Stream.with_index()
    |> Stream.map(fn {_change, index} ->
      if index >= period do
        period_changes = Enum.slice(changes, (index - period + 1)..index)

        gains = period_changes |> Enum.filter(&(&1 && &1 > 0)) |> Enum.sum()
        losses = period_changes |> Enum.filter(&(&1 && &1 < 0)) |> Enum.map(&abs/1) |> Enum.sum()

        avg_gain = gains / period
        avg_loss = losses / period

        if avg_loss == 0 do
          100.0
        else
          rs = avg_gain / avg_loss
          100.0 - 100.0 / (1.0 + rs)
        end
      else
        nil
      end
    end)
    |> Enum.to_list()
  end

  @doc """
  Calculate MACD (Moving Average Convergence Divergence).

  Returns a tuple of {macd_line, signal_line, histogram}.

  ## Parameters

  - `data` - List or Stream of numeric values (typically closing prices)
  - `fast_period` - Fast EMA period (default: 12)
  - `slow_period` - Slow EMA period (default: 26)
  - `signal_period` - Signal line EMA period (default: 9)

  ## Examples

      iex> prices = [12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30]
      iex> {macd, signal, histogram} = ExPostFacto.Indicators.macd(prices)
      iex> is_list(macd) and is_list(signal) and is_list(histogram)
      true
  """
  @spec macd(Enumerable.t(), pos_integer(), pos_integer(), pos_integer()) ::
          {[float() | nil], [float() | nil], [float() | nil]}
  def macd(data, fast_period \\ 12, slow_period \\ 26, signal_period \\ 9) do
    fast_ema = ema(data, fast_period)
    slow_ema = ema(data, slow_period)

    # MACD line is the difference between fast and slow EMA
    macd_line =
      Enum.zip(fast_ema, slow_ema)
      |> Enum.map(fn
        {nil, _} -> nil
        {_, nil} -> nil
        {fast, slow} -> fast - slow
      end)

    # Signal line is EMA of MACD line
    signal_line =
      macd_line
      |> Enum.filter(&(&1 != nil))
      |> ema(signal_period)
      |> pad_with_nils(length(macd_line))

    # Histogram is difference between MACD and signal line
    histogram =
      Enum.zip(macd_line, signal_line)
      |> Enum.map(fn
        {nil, _} -> nil
        {_, nil} -> nil
        {macd, signal} -> macd - signal
      end)

    {macd_line, signal_line, histogram}
  end

  # Helper to pad signal line with nils to match MACD line length
  defp pad_with_nils(signal_values, target_length) do
    current_length = length(signal_values)
    nil_count = target_length - current_length

    List.duplicate(nil, nil_count) ++ signal_values
  end

  @doc """
  Calculate Bollinger Bands.

  Returns a tuple of {upper_band, middle_band, lower_band}.

  ## Parameters

  - `data` - List or Stream of numeric values
  - `period` - Period for the moving average (default: 20)
  - `std_dev` - Number of standard deviations (default: 2)

  ## Examples

      iex> prices = [20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34]
      iex> {upper, middle, lower} = ExPostFacto.Indicators.bollinger_bands(prices, 10, 2)
      iex> is_list(upper) and is_list(middle) and is_list(lower)
      true
  """
  @spec bollinger_bands(Enumerable.t(), pos_integer(), number()) ::
          {[float() | nil], [float() | nil], [float() | nil]}
  def bollinger_bands(data, period \\ 20, std_dev \\ 2) do
    data_list = Enum.to_list(data)
    middle_band = sma(data_list, period)

    # Calculate standard deviation for each period
    std_devs =
      data_list
      |> Stream.with_index()
      |> Stream.map(fn {_value, index} ->
        if index + 1 >= period do
          period_data =
            data_list
            |> Enum.take(index + 1)
            |> Enum.take(-period)

          mean = Enum.sum(period_data) / period

          variance =
            period_data
            |> Enum.map(&:math.pow(&1 - mean, 2))
            |> Enum.sum()
            |> Kernel./(period)

          :math.sqrt(variance)
        else
          nil
        end
      end)
      |> Enum.to_list()

    # Calculate upper and lower bands
    upper_band =
      Enum.zip(middle_band, std_devs)
      |> Enum.map(fn
        {nil, _} -> nil
        {_, nil} -> nil
        {middle, std} -> middle + std_dev * std
      end)

    lower_band =
      Enum.zip(middle_band, std_devs)
      |> Enum.map(fn
        {nil, _} -> nil
        {_, nil} -> nil
        {middle, std} -> middle - std_dev * std
      end)

    {upper_band, middle_band, lower_band}
  end

  @doc """
  Calculate Average True Range (ATR).

  ATR measures volatility by decomposing the entire range of an asset price for that period.

  ## Parameters

  - `data` - List or Stream of OHLC data (maps with :high, :low, :close keys)
  - `period` - Period for ATR calculation (default: 14)

  ## Examples

      iex> ohlc_data = [
      ...>   %{high: 48.70, low: 47.79, close: 48.16},
      ...>   %{high: 48.72, low: 48.14, close: 48.61},
      ...>   %{high: 48.90, low: 48.39, close: 48.75}
      ...> ]
      iex> atr_values = ExPostFacto.Indicators.atr(ohlc_data, 2)
      iex> is_list(atr_values)
      true
  """
  @spec atr(Enumerable.t(), pos_integer()) :: [float() | nil]
  def atr(data, period \\ 14) when is_integer(period) and period > 0 do
    data
    |> Enum.to_list()
    |> calculate_true_ranges()
    |> sma(period)
  end

  # Calculate True Range for each period
  defp calculate_true_ranges([]), do: []
  defp calculate_true_ranges([_single]), do: [nil]

  defp calculate_true_ranges([prev | rest]) do
    calculate_true_ranges_helper(prev, rest, [nil])
  end

  defp calculate_true_ranges_helper(_prev, [], acc), do: Enum.reverse(acc)

  defp calculate_true_ranges_helper(prev, [current | rest], acc) do
    tr1 = current.high - current.low
    tr2 = abs(current.high - prev.close)
    tr3 = abs(current.low - prev.close)

    true_range = Enum.max([tr1, tr2, tr3])
    calculate_true_ranges_helper(current, rest, [true_range | acc])
  end

  @doc """
  Check if the first series crosses above the second series.

  Returns true if there was a crossover on the most recent data point.

  ## Parameters

  - `series1` - First data series (list of numbers)
  - `series2` - Second data series (list of numbers)

  ## Examples

      iex> fast_ma = [10, 11, 12, 13, 14]
      iex> slow_ma = [12, 12, 12, 12, 12]
      iex> ExPostFacto.Indicators.crossover?(fast_ma, slow_ma)
      true

      iex> fast_ma = [10, 11, 12]
      iex> slow_ma = [13, 13, 13]
      iex> ExPostFacto.Indicators.crossover?(fast_ma, slow_ma)
      false
  """
  @spec crossover?([number() | nil], [number() | nil]) :: boolean()
  def crossover?(series1, series2) when is_list(series1) and is_list(series2) do
    case {series1, series2} do
      {[current1, prev1 | _], [current2, prev2 | _]}
      when not is_nil(current1) and not is_nil(prev1) and
             not is_nil(current2) and not is_nil(prev2) ->
        # Previous: series1 <= series2, Current: series1 > series2
        prev1 <= prev2 and current1 > current2

      _ ->
        false
    end
  end

  @doc """
  Check if the first series crosses below the second series.

  Returns true if there was a crossover below on the most recent data point.

  ## Parameters

  - `series1` - First data series (list of numbers)
  - `series2` - Second data series (list of numbers)

  ## Examples

      iex> fast_ma = [14, 13, 12, 11, 10]
      iex> slow_ma = [12, 12, 12, 12, 12]
      iex> ExPostFacto.Indicators.crossunder?(fast_ma, slow_ma)
      true
  """
  @spec crossunder?([number() | nil], [number() | nil]) :: boolean()
  def crossunder?(series1, series2) when is_list(series1) and is_list(series2) do
    case {series1, series2} do
      {[current1, prev1 | _], [current2, prev2 | _]}
      when not is_nil(current1) and not is_nil(prev1) and
             not is_nil(current2) and not is_nil(prev2) ->
        # Previous: series1 >= series2, Current: series1 < series2
        prev1 >= prev2 and current1 < current2

      _ ->
        false
    end
  end
end
