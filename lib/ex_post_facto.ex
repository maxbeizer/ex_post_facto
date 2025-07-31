defmodule ExPostFacto do
  @moduledoc """
  ExPostFacto is a library for backtesting trading strategies. It is still under
  development but takes a lot of inspiration from various Python libraries in
  this space.
  """

  alias ExPostFacto.{
    DataPoint,
    InputData,
    Output,
    Result,
    StrategyContext
  }

  @actions [:buy, :sell, :close_buy, :close_sell]
  @type action :: :buy | :sell | :close_buy | :close_sell
  @type module_function_arguments :: {module :: atom(), function :: atom(), args :: list()}
  @type strategy_module :: {module :: atom(), opts :: keyword()}
  @type strategy :: module_function_arguments() | strategy_module()

  defmodule DataValidationError do
    @moduledoc false
    @doc false
    defexception message: "invalid data"
  end

  defmodule BacktestError do
    @moduledoc false
    @doc false
    defexception message: "unable to run backtest"
  end

  @doc """
  The main entry point of the library. This function takes in a list of HLOC
  data and a strategy that will be used to generate buy and sell signals.

  The strategy can be either:
  - A traditional MFA tuple: `{Module, :function, args}`
  - A Strategy behaviour module: `{Module, opts}` where Module implements ExPostFacto.Strategy

  Options may also be passed in for configuration.

  The function returns output struct or raises an error

  Supports multiple input formats:
  - List of maps (existing functionality)
  - CSV file path as string
  - JSON string or parsed data

  ## Examples

      iex> ExPostFacto.backtest!(nil, {Foo, :bar, []})
      ** (ExPostFacto.BacktestError) data cannot be nil

      iex> ExPostFacto.backtest!([], {Foo, :bar, []})
      ** (ExPostFacto.BacktestError) data cannot be empty

      iex> ExPostFacto.backtest!([%{o: 1.0, h: 2.0, l: 0.5, c: 1.0}], nil)
      ** (ExPostFacto.BacktestError) strategy cannot be nil

      # Using traditional MFA tuple
      iex> data = [%{o: 1.0, h: 2.0, l: 0.5, c: 1.0}]
      iex> output = ExPostFacto.backtest!(data, {ExPostFacto.ExampleStrategies.Noop, :noop, []})
      iex> match?(%ExPostFacto.Output{}, output)
      true

      # CSV file input
      iex> ExPostFacto.backtest!("path/to/data.csv", {MyStrategy, :call, []})
      %ExPostFacto.Output{}

      # This would be used with Strategy behaviour modules
      # iex> ExPostFacto.backtest!(data, {MyStrategy, [param: 10]})
  """
  @spec backtest!(
          data :: [DataPoint.t()] | String.t(),
          strategy :: strategy(),
          options :: keyword()
        ) ::
          Output.t() | no_return()
  def backtest!(data, strategy, options \\ []) do
    case backtest(data, strategy, options) do
      {:ok, output} -> output
      {:error, error} -> raise BacktestError, message: error
    end
  end

  @doc """
  The other main entry point of the library. This function takes in a list of
  HLOC data and a strategy that will be used to generate buy and sell signals.

  The strategy can be either:
  - A traditional MFA tuple: `{Module, :function, args}`
  - A Strategy behaviour module: `{Module, opts}` where Module implements ExPostFacto.Strategy

  Options may also be passed in for configuration.

  The function returns an ok or error tuple. In an ok tuple, the data, and a
  results struct are returned. In an error tuple, a string is returned with the
  error message.

  Supports multiple input formats:
  - List of maps (existing functionality)
  - CSV file path as string
  - JSON string or parsed data

  ## Examples

      iex> ExPostFacto.backtest(nil, {Foo, :bar, []})
      {:error, "data cannot be nil"}

      iex> ExPostFacto.backtest([], {Foo, :bar, []})
      {:error, "data cannot be empty"}

      iex> ExPostFacto.backtest([%{o: 1.0, h: 2.0, l: 0.5, c: 1.0}], nil)
      {:error, "strategy cannot be nil"}

      # Using traditional MFA tuple  
      iex> data = [%{o: 1.0, h: 2.0, l: 0.5, c: 1.0}]
      iex> result = ExPostFacto.backtest(data, {ExPostFacto.ExampleStrategies.Noop, :noop, []})
      iex> match?({:ok, %ExPostFacto.Output{}}, result)
      true

      # CSV file input
      iex> ExPostFacto.backtest("path/to/data.csv", {MyStrategy, :call, []})
      {:ok, %ExPostFacto.Output{}}

      # This would be used with Strategy behaviour modules
      # iex> ExPostFacto.backtest(data, {MyStrategy, [param: 10]})
  """
  @spec backtest(
          data :: [DataPoint.t()] | String.t(),
          strategy :: strategy(),
          options :: keyword()
        ) ::
          {:ok, Output.t()} | {:error, String.t()}
  def backtest(data, strategy, options \\ [])
  def backtest(nil, _strategy, _options), do: {:error, "data cannot be nil"}
  def backtest([], _, _options), do: {:error, "data cannot be empty"}
  def backtest(_data, nil, _options), do: {:error, "strategy cannot be nil"}

  def backtest(data, strategy, options) when is_binary(data) do
    case load_data_from_source(data) do
      {:ok, parsed_data} -> backtest(parsed_data, strategy, options)
      {:error, reason} -> {:error, "failed to load data: #{reason}"}
    end
  end

  def backtest(data, strategy, options) when is_list(data) do
    # Clean data first if cleaning is enabled (default: true)
    with {:ok, cleaned_data} <- maybe_clean_data(data, options),
         {:ok, validated_data} <- maybe_validate_data(cleaned_data, options) do
      
      # Initialize strategy if it's a behaviour-based strategy
      case strategy do
        {module, opts} when is_list(opts) ->
          case initialize_strategy_behaviour(module, opts) do
            {:ok, strategy_state} ->
              backtest_with_behaviour(validated_data, {module, strategy_state}, options)

            {:error, reason} ->
              {:error, "strategy initialization failed: #{inspect(reason)}"}
          end

        {_module, _function, _args} ->
          backtest_with_mfa(validated_data, strategy, options)

        _ ->
          {:error, "invalid strategy format"}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Handle behaviour-based strategies
  defp backtest_with_behaviour(data, {module, strategy_state}, options) do
    result = build_initial_result(data, options)

    # Start the strategy context
    {:ok, _pid} = StrategyContext.start_link()

    try do
      result =
        data
        |> Enum.map(&InputData.munge/1)
        |> Enum.with_index(fn datum, index -> {index, datum} end)
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.reduce({result, strategy_state}, &apply_behaviour_strategy(&1, &2, module))
        |> elem(0)
        |> Result.compile(options)

      {:ok, Output.new(data, {module, []}, result)}
    after
      StrategyContext.stop()
    end
  end

  # Handle traditional MFA strategies
  defp backtest_with_mfa(data, strategy, options) do
    result = build_initial_result(data, options)

    result =
      data
      |> Enum.map(&InputData.munge/1)
      |> Enum.with_index(fn datum, index -> {index, datum} end)
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.reduce(result, &apply_mfa_strategy(&1, &2, strategy))
      |> Result.compile(options)

    {:ok, Output.new(data, strategy, result)}
  end

  @doc """
  Loads data from various sources (CSV files, JSON, etc.).

  ## Examples

      iex> ExPostFacto.load_data_from_source("test/fixtures/sample.csv")
      {:ok, [
        %{open: 100.0, high: 105.0, low: 98.0, close: 102.0, volume: 1000000.0, timestamp: "2023-01-01"},
        %{open: 102.0, high: 108.0, low: 101.0, close: 106.0, volume: 1200000.0, timestamp: "2023-01-02"},
        %{open: 106.0, high: 110.0, low: 104.0, close: 108.0, volume: 900000.0, timestamp: "2023-01-03"}
      ]}
  """
  @spec load_data_from_source(String.t()) :: {:ok, [map()]} | {:error, String.t()}
  def load_data_from_source(source) when is_binary(source) do
    cond do
      String.ends_with?(source, ".csv") -> load_csv_data(source)
      String.starts_with?(source, "[") or String.starts_with?(source, "{") -> parse_json_data(source)
      File.exists?(source) -> load_csv_data(source)  # Default to CSV for existing files
      true -> {:error, "unsupported data format or file not found"}
    end
  end

  @spec maybe_validate_data([map()], keyword()) :: {:ok, [map()]} | {:error, String.t()}
  defp maybe_validate_data(data, options) do
    if Keyword.get(options, :validate_data, true) do
      case validate_data(data) do
        :ok -> {:ok, data}
        {:error, reason} -> {:error, reason}
      end
    else
      {:ok, data}
    end
  end

  @spec maybe_clean_data([map()], keyword()) :: {:ok, [map()]} | {:error, String.t()}
  defp maybe_clean_data(data, options) do
    if Keyword.get(options, :clean_data, true) do
      clean_data(data)
    else
      {:ok, data}
    end
  end

  @spec load_csv_data(String.t()) :: {:ok, [map()]} | {:error, String.t()}
  defp load_csv_data(file_path) do
    case File.read(file_path) do
      {:ok, content} -> parse_csv_content(content)
      {:error, reason} -> {:error, "failed to read file: #{reason}"}
    end
  end

  @spec parse_csv_content(String.t()) :: {:ok, [map()]} | {:error, String.t()}
  defp parse_csv_content(content) do
    try do
      lines = String.split(content, "\n", trim: true)
      
      case lines do
        [] -> {:error, "empty CSV file"}
        [header | data_lines] ->
          headers = parse_csv_header(header)
          data = Enum.map(data_lines, &parse_csv_line(&1, headers))
          {:ok, data}
      end
    rescue
      _ -> {:error, "failed to parse CSV content"}
    end
  end

  @spec parse_csv_header(String.t()) :: [atom()]
  defp parse_csv_header(header_line) do
    header_line
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&normalize_csv_header/1)
  end

  @spec normalize_csv_header(String.t()) :: atom()
  defp normalize_csv_header(header) do
    case String.downcase(header) do
      "date" -> :timestamp
      "time" -> :timestamp
      "timestamp" -> :timestamp
      "open" -> :open
      "high" -> :high
      "low" -> :low
      "close" -> :close
      "adj close" -> :adj_close
      "volume" -> :volume
      _ -> String.to_atom(String.downcase(String.replace(header, " ", "_")))
    end
  end

  @spec parse_csv_line(String.t(), [atom()]) :: map()
  defp parse_csv_line(line, headers) do
    values = String.split(line, ",")
    
    parsed_data = headers
    |> Enum.zip(values)
    |> Enum.into(%{}, fn {header, value} ->
      {header, parse_csv_value(value, header)}
    end)

    # Handle special case where we have both close and adj_close
    # Prefer adj_close if available
    case {Map.get(parsed_data, :close), Map.get(parsed_data, :adj_close)} do
      {_close, adj_close} when not is_nil(adj_close) ->
        Map.put(parsed_data, :close, adj_close)
      _ ->
        parsed_data
    end
  end

  @spec parse_csv_value(String.t(), atom()) :: any()
  defp parse_csv_value(value, header) when header in [:timestamp, :date, :time] do
    String.trim(value)
  end
  defp parse_csv_value(value, _header) do
    case Float.parse(String.trim(value)) do
      {float_val, ""} -> float_val
      _ -> String.trim(value)
    end
  end

  @spec parse_json_data(String.t()) :: {:ok, [map()]} | {:error, String.t()}
  defp parse_json_data(json_string) do
    try do
      # Simple JSON parsing - for production would use Jason or Poison
      case Code.eval_string(json_string) do
        {data, _} when is_list(data) -> {:ok, data}
        {data, _} when is_map(data) -> {:ok, [data]}
        _ -> {:error, "invalid JSON format"}
      end
    rescue
      _ -> {:error, "failed to parse JSON"}
    end
  end

  defp initialize_strategy_behaviour(module, opts) do
    # Force module loading and check if it's compiled
    case Code.ensure_loaded(module) do
      {:module, _} ->
        if function_exported?(module, :init, 1) do
          module.init(opts)
        else
          {:error, "module #{inspect(module)} does not implement ExPostFacto.Strategy behaviour"}
        end

      {:error, _reason} ->
        {:error, "module #{inspect(module)} could not be loaded"}
    end
  end

  @spec apply_behaviour_strategy(
          [{index :: non_neg_integer(), datum :: DataPoint.t()}],
          {result :: Result.t(), strategy_state :: any()},
          module :: atom()
        ) :: {Result.t(), any()}
  defp apply_behaviour_strategy(
         [{_index, datum}, {next_index, next_datum}],
         {result, strategy_state},
         module
       ) do
    # Set up context for the strategy
    :ok = StrategyContext.set_context(datum, result)

    # Call the strategy's next function
    case module.next(strategy_state) do
      {:ok, new_strategy_state} ->
        # Check if an action was set
        action = StrategyContext.get_action()
        StrategyContext.clear_action()

        updated_result =
          if action && action in @actions do
            Result.add_data_point(result, next_index, next_datum, action)
          else
            result
          end

        {updated_result, new_strategy_state}

      {:error, _reason} ->
        # If strategy fails, continue without taking action
        {result, strategy_state}
    end
  end

  @spec apply_mfa_strategy(
          [{index :: non_neg_integer(), datum :: DataPoint.t()}],
          result :: Result.t(),
          strategy :: module_function_arguments()
        ) :: Result.t()
  defp apply_mfa_strategy([{_index, datum}, {next_index, next_datum}], result, {m, f, _a}) do
    action = apply(m, f, [datum, result])

    cond do
      action in @actions ->
        Result.add_data_point(result, next_index, next_datum, action)

      true ->
        result
    end
  end

  @spec build_initial_result(
          data :: [DataPoint.t()],
          options :: keyword()
        ) :: Result.t()
  defp build_initial_result(data, options) do
    start_date = hd(data) |> InputData.munge() |> Map.get(:timestamp)
    end_date = List.last(data) |> InputData.munge() |> Map.get(:timestamp)

    options
    |> Keyword.put(:start_date, start_date)
    |> Keyword.put(:end_date, end_date)
    |> Result.new()
  end

  @doc """
  Validates OHLCV data structure and values.

  Returns `:ok` if data is valid, or `{:error, reason}` if invalid.

  ## Examples

      iex> ExPostFacto.validate_data([%{open: 1.0, high: 2.0, low: 0.5, close: 1.5}])
      :ok

      iex> ExPostFacto.validate_data([%{high: 1.0, low: 2.0, open: 1.5, close: 1.5}])
      {:error, "data point 0: invalid OHLC data: high (1.0) must be >= low (2.0)"}

      iex> ExPostFacto.validate_data([])
      {:error, "data cannot be empty"}
  """
  @spec validate_data(data :: [map()] | map()) :: :ok | {:error, String.t()}
  def validate_data(data)
  def validate_data([]), do: {:error, "data cannot be empty"}
  def validate_data(nil), do: {:error, "data cannot be nil"}
  def validate_data(data) when is_list(data) do
    data
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {point, index}, _acc ->
      case validate_data_point(point) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, "data point #{index}: #{reason}"}}
      end
    end)
  end
  def validate_data(data) when is_map(data), do: validate_data_point(data)

  @doc """
  Cleans and preprocesses OHLCV data.

  Removes invalid data points, sorts by timestamp, and handles missing values.

  ## Examples

      iex> dirty_data = [
      ...>   %{open: 1.0, high: 2.0, low: 0.5, close: 1.5, timestamp: "2023-01-02"},
      ...>   %{open: nil, high: 1.8, low: 0.8, close: 1.2, timestamp: "2023-01-01"},
      ...>   %{open: 1.2, high: 1.9, low: 0.9, close: 1.4, timestamp: "2023-01-03"}
      ...> ]
      iex> {:ok, cleaned} = ExPostFacto.clean_data(dirty_data)
      iex> length(cleaned)
      2
  """
  @spec clean_data(data :: [map()]) :: {:ok, [map()]} | {:error, String.t()}
  def clean_data(data)
  def clean_data([]), do: {:ok, []}
  def clean_data(nil), do: {:error, "data cannot be nil"}
  def clean_data(data) when is_list(data) do
    cleaned_data =
      data
      |> Enum.filter(&is_valid_data_point?/1)
      |> Enum.sort_by(&get_timestamp_for_sorting/1)
      |> Enum.uniq_by(&get_timestamp_for_sorting/1)

    {:ok, cleaned_data}
  end

  @spec validate_data_point(map()) :: :ok | {:error, String.t()}
  defp validate_data_point(point) when is_map(point) do
    with :ok <- validate_required_fields(point),
         :ok <- validate_numeric_values(point),
         :ok <- validate_ohlc_relationship(point) do
      :ok
    end
  end
  defp validate_data_point(_), do: {:error, "data point must be a map"}

  @spec validate_required_fields(map()) :: :ok | {:error, String.t()}
  defp validate_required_fields(point) do
    required_fields = [:open, :high, :low, :close]
    alt_fields = [:o, :h, :l, :c]
    
    has_required = Enum.all?(required_fields, &Map.has_key?(point, &1))
    has_alt = Enum.all?(alt_fields, &Map.has_key?(point, &1))

    cond do
      has_required or has_alt -> :ok
      true -> {:error, "missing required OHLC fields"}
    end
  end

  @spec validate_numeric_values(map()) :: :ok | {:error, String.t()}
  defp validate_numeric_values(point) do
    values = [
      get_field_value(point, :open, :o),
      get_field_value(point, :high, :h),
      get_field_value(point, :low, :l),
      get_field_value(point, :close, :c)
    ]

    cond do
      Enum.any?(values, &is_nil/1) -> {:error, "OHLC values cannot be nil"}
      Enum.any?(values, &(!is_number(&1))) -> {:error, "OHLC values must be numeric"}
      Enum.any?(values, &(&1 < 0)) -> {:error, "OHLC values must be non-negative"}
      true -> :ok
    end
  end

  @spec validate_ohlc_relationship(map()) :: :ok | {:error, String.t()}
  defp validate_ohlc_relationship(point) do
    high = get_field_value(point, :high, :h)
    low = get_field_value(point, :low, :l)
    open = get_field_value(point, :open, :o)
    close = get_field_value(point, :close, :c)

    cond do
      high < low -> {:error, "invalid OHLC data: high (#{high}) must be >= low (#{low})"}
      open > high -> {:error, "invalid OHLC data: open (#{open}) must be <= high (#{high})"}
      open < low -> {:error, "invalid OHLC data: open (#{open}) must be >= low (#{low})"}
      close > high -> {:error, "invalid OHLC data: close (#{close}) must be <= high (#{high})"}
      close < low -> {:error, "invalid OHLC data: close (#{close}) must be >= low (#{low})"}
      true -> :ok
    end
  end

  @spec is_valid_data_point?(map()) :: boolean()
  defp is_valid_data_point?(point) do
    case validate_data_point(point) do
      :ok -> true
      {:error, _} -> false
    end
  end

  @spec get_field_value(map(), atom(), atom()) :: any()
  defp get_field_value(point, primary_key, alt_key) do
    Map.get(point, primary_key) || Map.get(point, alt_key)
  end

  @spec get_timestamp_for_sorting(map()) :: String.t() | nil
  defp get_timestamp_for_sorting(point) do
    Map.get(point, :timestamp) || Map.get(point, :t) || ""
  end
end
