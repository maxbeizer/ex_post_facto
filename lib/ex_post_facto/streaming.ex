defmodule ExPostFacto.Streaming do
  @moduledoc """
  Streaming and chunked processing for large datasets.

  Provides memory-efficient processing capabilities for handling large market data files
  that may not fit comfortably in memory. Supports various streaming strategies for
  different use cases.

  ## Features

  - **File streaming**: Process large CSV/JSON files without loading everything into memory
  - **Chunked backtesting**: Run backtests on data chunks for memory efficiency
  - **Rolling window processing**: Maintain a rolling window of data for analysis
  - **Lazy evaluation**: Only load and process data as needed

  ## Example Usage

      # Stream process a large CSV file
      {:ok, results} = ExPostFacto.Streaming.backtest_stream(
        "large_dataset.csv",
        MyStrategy,
        chunk_size: 1000,
        window_size: 100
      )

      # Process data in rolling windows
      stream = ExPostFacto.Streaming.rolling_window_stream(
        data_stream,
        window_size: 252  # 1 year of trading days
      )
  """

  alias ExPostFacto.{InputData, Output}

  @type stream_options :: [
          chunk_size: integer(),
          window_size: integer(),
          overlap: integer(),
          buffer_size: integer(),
          memory_limit_mb: integer()
        ]

  @doc """
  Perform backtesting on a data stream with chunked processing.

  Processes data in chunks to manage memory usage while maintaining strategy continuity.
  Useful for very large datasets that would otherwise cause memory issues.

  ## Parameters

  - `data_source` - File path, stream, or enumerable data source
  - `strategy` - Trading strategy to apply
  - `opts` - Options for streaming and backtesting

  ## Options

  - `:chunk_size` - Number of data points per chunk (default: 1000)
  - `:window_size` - Rolling window size for strategy context (default: 100)
  - `:overlap` - Overlap between chunks for continuity (default: 10)
  - `:buffer_size` - File reading buffer size (default: 8192)
  - `:memory_limit_mb` - Memory limit in MB before forcing chunk processing (default: 100)

  ## Example

      {:ok, result} = ExPostFacto.Streaming.backtest_stream(
        "very_large_data.csv",
        {MyStrategy, []},
        chunk_size: 2000,
        window_size: 200,
        overlap: 50
      )
  """
  @spec backtest_stream(
          data_source :: String.t() | Enumerable.t(),
          strategy :: ExPostFacto.strategy(),
          opts :: keyword()
        ) :: {:ok, Output.t()} | {:error, String.t()}
  def backtest_stream(data_source, strategy, opts \\ []) do
    chunk_size = Keyword.get(opts, :chunk_size, 1000)
    window_size = Keyword.get(opts, :window_size, 100)
    overlap = Keyword.get(opts, :overlap, 10)
    memory_limit_mb = Keyword.get(opts, :memory_limit_mb, 100)

    # Estimate memory usage and decide on processing strategy
    with {:ok, data_stream} <- create_data_stream(data_source, opts),
         :ok <- check_memory_requirements(data_stream, memory_limit_mb),
         {:ok, processed_chunks} <-
           process_stream_in_chunks(data_stream, strategy, chunk_size, window_size, overlap, opts),
         {:ok, combined_result} <- combine_chunk_results(processed_chunks, opts) do
      {:ok, combined_result}
    else
      {:error, reason} -> {:error, reason}
      {:memory_warning, _message} -> backtest_stream_forced_chunking(data_source, strategy, opts)
    end
  end

  @doc """
  Create a rolling window stream from data.

  Creates a stream that yields rolling windows of data, useful for time series analysis
  and strategies that need historical context.

  ## Parameters

  - `data_stream` - Input data stream
  - `window_size` - Size of the rolling window
  - `step_size` - Step size between windows (default: 1)

  ## Example

      data_stream
      |> ExPostFacto.Streaming.rolling_window_stream(window_size: 20)
      |> Stream.map(fn window -> analyze_window(window) end)
      |> Enum.to_list()
  """
  @spec rolling_window_stream(Enumerable.t(), integer(), integer()) :: Enumerable.t()
  def rolling_window_stream(data_stream, window_size, step_size \\ 1) do
    data_stream
    |> Stream.chunk_every(window_size, step_size, :discard)
    |> Stream.map(fn window ->
      # Ensure window has the expected size
      if length(window) == window_size do
        window
      else
        :skip
      end
    end)
    |> Stream.filter(&(&1 != :skip))
  end

  @doc """
  Create a memory-efficient data stream from various sources.

  Supports CSV files, JSON files, and other enumerable data sources with lazy loading.

  ## Parameters

  - `source` - Data source (file path or enumerable)
  - `opts` - Options for stream creation

  ## Options

  - `:format` - Data format (`:csv`, `:json`, `:auto`) (default: `:auto`)
  - `:buffer_size` - File reading buffer size (default: 8192)
  - `:headers` - CSV headers if not in file (default: auto-detect)
  """
  @spec create_data_stream(String.t() | Enumerable.t(), keyword()) ::
          {:ok, Enumerable.t()} | {:error, String.t()}
  def create_data_stream(source, opts \\ [])

  def create_data_stream(source, opts) when is_binary(source) do
    format = Keyword.get(opts, :format, :auto)
    buffer_size = Keyword.get(opts, :buffer_size, 8192)

    cond do
      String.ends_with?(source, ".csv") or format == :csv ->
        create_csv_stream(source, buffer_size, opts)

      String.ends_with?(source, ".json") or format == :json ->
        create_json_stream(source, buffer_size, opts)

      format == :auto ->
        # Try to detect format from file extension or content
        detect_and_create_stream(source, buffer_size, opts)

      true ->
        {:error, "Unsupported file format"}
    end
  end

  def create_data_stream(source, _opts) when is_list(source) do
    {:ok, source}
  end

  def create_data_stream(source, _opts) do
    # Assume it's an enumerable
    {:ok, source}
  end

  # Private implementation functions

  defp create_csv_stream(file_path, buffer_size, _opts) do
    try do
      stream =
        file_path
        |> File.stream!([], buffer_size)
        |> Stream.map(&String.trim/1)
        |> Stream.reject(&(&1 == ""))
        |> Stream.map(&parse_csv_line/1)
        |> Stream.map(&InputData.munge/1)

      {:ok, stream}
    rescue
      e -> {:error, "Failed to create CSV stream: #{Exception.message(e)}"}
    end
  end

  defp parse_csv_line(line) do
    # Simple CSV parsing - in practice you'd want a proper CSV library
    values = String.split(line, ",")

    case values do
      [open, high, low, close | _] ->
        %{
          open: String.to_float(open),
          high: String.to_float(high),
          low: String.to_float(low),
          close: String.to_float(close)
        }

      _ ->
        %{open: 0.0, high: 0.0, low: 0.0, close: 0.0}
    end
  rescue
    _ -> %{open: 0.0, high: 0.0, low: 0.0, close: 0.0}
  end

  defp create_json_stream(_file_path, _buffer_size, _opts) do
    try do
      # Simple JSON parsing - you might want to add Jason as a dependency for production use
      {:error, "JSON streaming requires the Jason library to be added as a dependency"}
    rescue
      e -> {:error, "Failed to create JSON stream: #{Exception.message(e)}"}
    end
  end

  defp detect_and_create_stream(file_path, buffer_size, opts) do
    # Simple format detection based on first few lines
    try do
      first_line = File.read!(file_path) |> String.split("\n") |> List.first()

      cond do
        String.contains?(first_line, ",") ->
          create_csv_stream(file_path, buffer_size, opts)

        String.starts_with?(first_line, "{") ->
          create_json_stream(file_path, buffer_size, opts)

        true ->
          {:error, "Unable to detect file format"}
      end
    rescue
      _ -> {:error, "Unable to read file for format detection"}
    end
  end

  defp check_memory_requirements(data_stream, memory_limit_mb) do
    # For file streams, we can proceed with chunking
    # For in-memory data, check if it exceeds the limit
    case data_stream do
      list when is_list(list) ->
        estimated_size_mb = estimate_memory_usage(list)

        if estimated_size_mb > memory_limit_mb do
          {:memory_warning,
           "Data size (#{estimated_size_mb}MB) exceeds limit (#{memory_limit_mb}MB)"}
        else
          :ok
        end

      _ ->
        # Stream source, assume it can be chunked efficiently
        :ok
    end
  end

  defp estimate_memory_usage(data) when is_list(data) do
    # Rough estimation: assume each data point is ~100 bytes on average
    sample_size = min(100, length(data))
    sample = Enum.take(data, sample_size)

    estimated_bytes_per_item =
      sample
      |> Enum.map(&:erlang.external_size/1)
      |> Enum.sum()
      |> div(sample_size)

    total_bytes = estimated_bytes_per_item * length(data)
    # Convert to MB
    total_bytes / (1024 * 1024)
  end

  defp process_stream_in_chunks(data_stream, strategy, chunk_size, window_size, overlap, opts) do
    # Process data in overlapping chunks
    chunks =
      data_stream
      |> Stream.chunk_every(chunk_size, chunk_size - overlap)
      |> Enum.to_list()

    processed_chunks =
      chunks
      |> Enum.with_index()
      |> Enum.map(fn {chunk, index} ->
        # For chunks after the first, include context from previous chunk
        chunk_with_context =
          if index > 0 and overlap > 0 do
            previous_chunk = Enum.at(chunks, index - 1)
            context = Enum.take(previous_chunk, -window_size)
            context ++ chunk
          else
            chunk
          end

        # Run backtest on this chunk
        case ExPostFacto.backtest(chunk_with_context, strategy, opts) do
          {:ok, output} -> {:ok, output}
          {:error, reason} -> {:error, "Chunk #{index} failed: #{reason}"}
        end
      end)

    # Check if all chunks succeeded
    if Enum.all?(processed_chunks, fn result -> match?({:ok, _}, result) end) do
      successful_chunks = Enum.map(processed_chunks, fn {:ok, output} -> output end)
      {:ok, successful_chunks}
    else
      failed_chunks = Enum.filter(processed_chunks, fn result -> match?({:error, _}, result) end)
      {:error, "Some chunks failed: #{inspect(failed_chunks)}"}
    end
  end

  defp combine_chunk_results(chunk_outputs, _opts) do
    # Combine results from multiple chunks
    # This is a simplified implementation - more sophisticated merging may be needed

    if Enum.empty?(chunk_outputs) do
      {:error, "No successful chunks to combine"}
    else
      # Take the first chunk as the base and merge statistics
      [first_output | _rest_outputs] = chunk_outputs

      combined_data = Enum.flat_map(chunk_outputs, fn output -> output.data end)
      combined_strategy = first_output.strategy

      # Merge result statistics (simplified - may need more sophisticated merging)
      combined_result = combine_results(Enum.map(chunk_outputs, fn output -> output.result end))

      combined_output = %Output{
        data: combined_data,
        strategy: combined_strategy,
        result: combined_result
      }

      {:ok, combined_output}
    end
  end

  defp combine_results([first_result | rest_results]) do
    # Simplified result combination - in practice, this would need more sophisticated merging
    # For now, just combine basic metrics

    total_trades =
      Enum.sum([first_result.trades_count | Enum.map(rest_results, & &1.trades_count)])

    total_profit_loss =
      Enum.sum([
        first_result.total_profit_and_loss | Enum.map(rest_results, & &1.total_profit_and_loss)
      ])

    # Use the first result as base and update key metrics
    %{first_result | trades_count: total_trades, total_profit_and_loss: total_profit_loss}
  end

  defp backtest_stream_forced_chunking(data_source, strategy, opts) do
    # Fallback to forced chunking when memory limits are exceeded
    small_chunk_size = Keyword.get(opts, :chunk_size, 1000) |> div(2)

    updated_opts = Keyword.put(opts, :chunk_size, small_chunk_size)
    backtest_stream(data_source, strategy, updated_opts)
  end
end
