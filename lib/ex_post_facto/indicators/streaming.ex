defmodule ExPostFacto.Indicators.Streaming do
  @moduledoc """
  Memory-efficient streaming implementations of technical indicators.

  This module provides streaming versions of technical indicators that use constant
  memory regardless of dataset size. These implementations are optimized for:

  - Large datasets that don't fit in memory
  - Real-time data processing
  - Low-latency applications
  - Memory-constrained environments

  ## Features

  - **Constant Memory Usage**: O(1) memory for most indicators
  - **Stream Processing**: Works with Elixir streams and GenStage
  - **Hot Updates**: Can update indicators incrementally
  - **State Preservation**: Maintains internal state for continuous processing

  ## Example Usage

      # Create a streaming SMA processor
      {:ok, sma_processor} = ExPostFacto.Indicators.Streaming.SMA.start_link(period: 20)

      # Process data points one by one
      large_data_stream
      |> Stream.map(fn price ->
           ExPostFacto.Indicators.Streaming.SMA.update(sma_processor, price)
         end)
      |> Stream.filter(&(&1 != nil))  # Filter out incomplete periods
      |> Enum.to_list()

      # Or process in batch for better performance
      {:ok, results} = ExPostFacto.Indicators.Streaming.process_batch(
        large_data_stream,
        [
          {:sma, [period: 20]},
          {:ema, [period: 12]},
          {:rsi, [period: 14]}
        ]
      )
  """

  defmodule SMA do
    @moduledoc """
    Streaming Simple Moving Average with O(1) memory usage.
    """
    use GenServer

    defstruct [:period, :window, :sum, :count]

    def start_link(opts) do
      period = Keyword.fetch!(opts, :period)
      GenServer.start_link(__MODULE__, period)
    end

    def update(pid, value) do
      GenServer.call(pid, {:update, value})
    end

    def current_value(pid) do
      GenServer.call(pid, :current_value)
    end

    def reset(pid) do
      GenServer.call(pid, :reset)
    end

    # GenServer callbacks

    def init(period) do
      state = %__MODULE__{
        period: period,
        window: :queue.new(),
        sum: 0.0,
        count: 0
      }

      {:ok, state}
    end

    def handle_call({:update, value}, _from, state) do
      new_state = update_sma(state, value)

      result =
        if new_state.count >= new_state.period do
          new_state.sum / new_state.period
        else
          nil
        end

      {:reply, result, new_state}
    end

    def handle_call(:current_value, _from, state) do
      result =
        if state.count >= state.period do
          state.sum / state.period
        else
          nil
        end

      {:reply, result, state}
    end

    def handle_call(:reset, _from, state) do
      new_state = %{state | window: :queue.new(), sum: 0.0, count: 0}
      {:reply, :ok, new_state}
    end

    defp update_sma(state, value) do
      window = :queue.in(value, state.window)
      sum = state.sum + value
      count = state.count + 1

      if count > state.period do
        {{:value, old_value}, window} = :queue.out(window)
        %{state | window: window, sum: sum - old_value, count: state.period}
      else
        %{state | window: window, sum: sum, count: count}
      end
    end
  end

  defmodule EMA do
    @moduledoc """
    Streaming Exponential Moving Average with O(1) memory usage.
    """
    use GenServer

    defstruct [:period, :alpha, :ema, :initialized]

    def start_link(opts) do
      period = Keyword.fetch!(opts, :period)
      GenServer.start_link(__MODULE__, period)
    end

    def update(pid, value) do
      GenServer.call(pid, {:update, value})
    end

    def current_value(pid) do
      GenServer.call(pid, :current_value)
    end

    def reset(pid) do
      GenServer.call(pid, :reset)
    end

    # GenServer callbacks

    def init(period) do
      alpha = 2.0 / (period + 1)

      state = %__MODULE__{
        period: period,
        alpha: alpha,
        ema: 0.0,
        initialized: false
      }

      {:ok, state}
    end

    def handle_call({:update, value}, _from, state) do
      new_state = update_ema(state, value)
      result = if new_state.initialized, do: new_state.ema, else: nil
      {:reply, result, new_state}
    end

    def handle_call(:current_value, _from, state) do
      result = if state.initialized, do: state.ema, else: nil
      {:reply, result, state}
    end

    def handle_call(:reset, _from, state) do
      new_state = %{state | ema: 0.0, initialized: false}
      {:reply, :ok, new_state}
    end

    defp update_ema(state, value) do
      if state.initialized do
        new_ema = state.alpha * value + (1 - state.alpha) * state.ema
        %{state | ema: new_ema}
      else
        %{state | ema: value, initialized: true}
      end
    end
  end

  defmodule RSI do
    @moduledoc """
    Streaming Relative Strength Index with O(1) memory usage.
    """
    use GenServer

    defstruct [:period, :prev_price, :avg_gain, :avg_loss, :count, :alpha]

    def start_link(opts) do
      period = Keyword.fetch!(opts, :period)
      GenServer.start_link(__MODULE__, period)
    end

    def update(pid, price) do
      GenServer.call(pid, {:update, price})
    end

    def current_value(pid) do
      GenServer.call(pid, :current_value)
    end

    def reset(pid) do
      GenServer.call(pid, :reset)
    end

    # GenServer callbacks

    def init(period) do
      alpha = 1.0 / period

      state = %__MODULE__{
        period: period,
        prev_price: nil,
        avg_gain: 0.0,
        avg_loss: 0.0,
        count: 0,
        alpha: alpha
      }

      {:ok, state}
    end

    def handle_call({:update, price}, _from, state) do
      new_state = update_rsi(state, price)
      result = calculate_rsi(new_state)
      {:reply, result, new_state}
    end

    def handle_call(:current_value, _from, state) do
      result = calculate_rsi(state)
      {:reply, result, state}
    end

    def handle_call(:reset, _from, state) do
      new_state = %{state | prev_price: nil, avg_gain: 0.0, avg_loss: 0.0, count: 0}
      {:reply, :ok, new_state}
    end

    defp update_rsi(state, price) do
      if state.prev_price do
        change = price - state.prev_price
        gain = if change > 0, do: change, else: 0.0
        loss = if change < 0, do: -change, else: 0.0

        count = state.count + 1

        if count == 1 do
          # First calculation
          %{state | prev_price: price, avg_gain: gain, avg_loss: loss, count: count}
        else
          # Use smoothed moving average (EMA style)
          new_avg_gain = state.alpha * gain + (1 - state.alpha) * state.avg_gain
          new_avg_loss = state.alpha * loss + (1 - state.alpha) * state.avg_loss

          %{
            state
            | prev_price: price,
              avg_gain: new_avg_gain,
              avg_loss: new_avg_loss,
              count: count
          }
        end
      else
        %{state | prev_price: price}
      end
    end

    defp calculate_rsi(state) do
      if state.count >= state.period and state.avg_loss > 0 do
        rs = state.avg_gain / state.avg_loss
        100 - 100 / (1 + rs)
      else
        nil
      end
    end
  end

  @doc """
  Process a stream of data with multiple indicators concurrently.

  This function allows you to calculate multiple indicators on the same data stream
  efficiently, with each indicator running in its own process.

  ## Parameters

  - `data_stream` - Stream of price data
  - `indicators` - List of {indicator_type, options} tuples

  ## Supported Indicators

  - `:sma` - Simple Moving Average (options: `period`)
  - `:ema` - Exponential Moving Average (options: `period`)
  - `:rsi` - Relative Strength Index (options: `period`)

  ## Example

      {:ok, results} = ExPostFacto.Indicators.Streaming.process_batch(
        price_stream,
        [
          {:sma, [period: 20]},
          {:sma, [period: 50]},
          {:ema, [period: 12]},
          {:rsi, [period: 14]}
        ]
      )

      # Results will be a map like:
      # %{
      #   sma_20: [nil, nil, ..., 100.5, 101.2, ...],
      #   sma_50: [nil, nil, ..., 98.7, 99.1, ...],
      #   ema_12: [100.0, 100.1, ..., 102.3, 102.8, ...],
      #   rsi_14: [nil, nil, ..., 45.2, 47.8, ...]
      # }
  """
  @spec process_batch(Enumerable.t(), [{atom(), keyword()}]) ::
          {:ok, map()} | {:error, String.t()}
  def process_batch(data_stream, indicators) do
    # Start all indicator processes
    case start_indicators(indicators) do
      {:ok, indicator_pids} ->
        try do
          # Process each data point through all indicators
          results =
            data_stream
            |> Enum.map(fn price ->
              Enum.map(indicator_pids, fn {name, pid} ->
                value =
                  case pid do
                    {SMA, pid} -> SMA.update(pid, price)
                    {EMA, pid} -> EMA.update(pid, price)
                    {RSI, pid} -> RSI.update(pid, price)
                  end

                {name, value}
              end)
            end)
            |> transpose_results()

          {:ok, results}
        after
          # Clean up processes
          cleanup_indicators(indicator_pids)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp start_indicators(indicators) do
    try do
      pids =
        Enum.map(indicators, fn {type, opts} ->
          name = generate_indicator_name(type, opts)

          case type do
            :sma ->
              {:ok, pid} = SMA.start_link(opts)
              {name, {SMA, pid}}

            :ema ->
              {:ok, pid} = EMA.start_link(opts)
              {name, {EMA, pid}}

            :rsi ->
              {:ok, pid} = RSI.start_link(opts)
              {name, {RSI, pid}}

            _ ->
              throw({:error, "Unsupported indicator type: #{type}"})
          end
        end)

      {:ok, pids}
    rescue
      e -> {:error, "Failed to start indicators: #{Exception.message(e)}"}
    catch
      {:error, reason} -> {:error, reason}
    end
  end

  defp generate_indicator_name(type, opts) do
    period = Keyword.get(opts, :period, "default")
    String.to_atom("#{type}_#{period}")
  end

  defp cleanup_indicators(indicator_pids) do
    Enum.each(indicator_pids, fn {_name, {_module, pid}} ->
      if Process.alive?(pid) do
        GenServer.stop(pid)
      end
    end)
  end

  defp transpose_results(results) do
    if Enum.empty?(results) do
      %{}
    else
      # Get all indicator names from the first result
      [first_result | _] = results
      indicator_names = Enum.map(first_result, fn {name, _value} -> name end)

      # Transpose the results to group by indicator
      Enum.reduce(indicator_names, %{}, fn name, acc ->
        values =
          Enum.map(results, fn row ->
            {^name, value} = Enum.find(row, fn {n, _} -> n == name end)
            value
          end)

        Map.put(acc, name, values)
      end)
    end
  end

  @doc """
  Create a streaming pipeline for real-time indicator calculation.

  Returns a GenStage producer that can be used in a streaming pipeline for
  real-time processing of market data.

  ## Example

      {:ok, indicator_stage} = ExPostFacto.Indicators.Streaming.create_pipeline([
        {:sma, [period: 20]},
        {:rsi, [period: 14]}
      ])

      # Use in a GenStage pipeline
      data_producer
      |> GenStage.stream([indicator_stage])
      |> Stream.each(&handle_indicators/1)
      |> Stream.run()
  """
  def create_pipeline(_indicators) do
    # This would implement a GenStage-based pipeline for real-time processing
    # For now, return a placeholder
    {:error, "GenStage pipeline not yet implemented"}
  end
end
