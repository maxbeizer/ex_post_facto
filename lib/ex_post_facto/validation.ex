defmodule ExPostFacto.Validation do
  @moduledoc """
  Enhanced validation and error handling for ExPostFacto.

  This module provides comprehensive input validation, meaningful error messages,
  strategy validation, runtime warnings for common issues, and debug mode support
  to significantly improve the developer experience and make the library more robust.

  ## Features

  - Data validation with detailed error messages
  - Strategy validation and common issue detection
  - Runtime warnings for performance and correctness issues
  - Debug mode for strategy development
  - Context-aware error reporting
  """

  alias ExPostFacto.{Result, Strategy}

  @type validation_result :: :ok | {:error, String.t()} | {:warning, String.t()}
  @type validation_context :: %{
          data_points: non_neg_integer(),
          strategy: any(),
          options: keyword(),
          debug_mode: boolean()
        }

  # Custom exception types for better error handling
  defmodule ValidationError do
    @moduledoc "Raised when data validation fails"
    defexception [:message, :context, :suggestions]

    @impl true
    def exception(opts) when is_list(opts) do
      message = Keyword.get(opts, :message, "Validation failed")
      context = Keyword.get(opts, :context, %{})
      suggestions = Keyword.get(opts, :suggestions, [])

      %__MODULE__{
        message: message,
        context: context,
        suggestions: suggestions
      }
    end

    def exception(message) when is_binary(message) do
      %__MODULE__{message: message, context: %{}, suggestions: []}
    end
  end

  defmodule StrategyError do
    @moduledoc "Raised when strategy validation or execution fails"
    defexception [:message, :strategy, :suggestions, :debug_info]

    @impl true
    def exception(opts) when is_list(opts) do
      message = Keyword.get(opts, :message, "Strategy error")
      strategy = Keyword.get(opts, :strategy)
      suggestions = Keyword.get(opts, :suggestions, [])
      debug_info = Keyword.get(opts, :debug_info, %{})

      %__MODULE__{
        message: message,
        strategy: strategy,
        suggestions: suggestions,
        debug_info: debug_info
      }
    end

    def exception(message) when is_binary(message) do
      %__MODULE__{message: message, strategy: nil, suggestions: [], debug_info: %{}}
    end
  end

  @doc """
  Validates data with enhanced error reporting and suggestions.

  Returns comprehensive validation results with detailed error messages,
  context information, and actionable suggestions for fixing issues.

  ## Options

  - `:debug` - Enable debug mode for detailed validation logging
  - `:strict` - Enable strict validation mode (more stringent checks)
  - `:context` - Additional context for error reporting

  ## Examples

      iex> data = [%{open: 100.0, high: 105.0, low: 98.0, close: 102.0}]
      iex> ExPostFacto.Validation.validate_data_enhanced(data)
      {:warning, "No volume data detected - some strategies may require volume information"}

      iex> invalid_data = [%{open: 100.0, high: 95.0, low: 98.0, close: 102.0}]
      iex> ExPostFacto.Validation.validate_data_enhanced(invalid_data)
      {:error, %ExPostFacto.Validation.ValidationError{
        message: "Invalid OHLC relationship in data point 0: high < low",
        context: %{high: 95.0, low: 98.0, point_index: 0},
        suggestions: ["Ensure high >= low for all data points", "Check data source for errors"]
      }}
  """
  @spec validate_data_enhanced([map()], keyword()) ::
          :ok | {:error, ValidationError.t()} | {:warning, String.t()}
  def validate_data_enhanced(data, options \\ [])

  def validate_data_enhanced([], _options),
    do: {:error, ValidationError.exception("Data cannot be empty")}

  def validate_data_enhanced(nil, _options),
    do: {:error, ValidationError.exception("Data cannot be nil")}

  def validate_data_enhanced(data, options) when is_list(data) do
    debug_mode = Keyword.get(options, :debug, false)
    strict_mode = Keyword.get(options, :strict, false)
    context = Keyword.get(options, :context, %{})

    if debug_mode do
      IO.puts(
        "[DEBUG] Validating #{length(data)} data points in #{if strict_mode, do: "strict", else: "normal"} mode"
      )
    end

    # Check for common issues first
    with :ok <- check_data_size(data, debug_mode),
         :ok <- check_data_quality(data, debug_mode),
         :ok <- validate_individual_points(data, strict_mode, debug_mode) do
      if debug_mode do
        IO.puts("[DEBUG] Data validation completed successfully")
      end

      # Check for warnings in normal mode
      case check_data_warnings(data, context) do
        {:warning, message} -> {:warning, message}
        :ok -> :ok
      end
    else
      {:error, error} -> {:error, error}
    end
  end

  @doc """
  Simple data validation for backward compatibility.
  Delegates to validate_data_enhanced/2 with default options.
  """
  @spec validate_data([map()], keyword()) ::
          :ok | {:error, ValidationError.t()} | {:warning, String.t()}
  def validate_data(data, options \\ []) do
    validate_data_enhanced(data, options)
  end

  @doc """
  Validates strategy configuration and detects common issues.

  Performs comprehensive strategy validation including:
  - Module existence and function availability
  - Parameter validation for strategy behaviours
  - Common configuration mistakes
  - Performance considerations

  ## Examples

      iex> ExPostFacto.Validation.validate_strategy({ExPostFacto.ExampleStrategies.Noop, :noop, []})
      {:warning, "Using no-operation strategy - this is typically for testing only"}

      iex> ExPostFacto.Validation.validate_strategy({NonExistentModule, :call, []})
      {:error, %ExPostFacto.Validation.StrategyError{
        message: "Module NonExistentModule does not exist",
        strategy: {NonExistentModule, :call, []},
        suggestions: [
          "Check module name spelling: NonExistentModule",
          "Ensure module is compiled and available",
          "Verify function exists: call/2",
          "Strategy function should accept (market_data, result, ...args)"
        ],
        debug_info: %{}
      }}
  """
  @spec validate_strategy(ExPostFacto.strategy(), keyword()) ::
          :ok | {:error, StrategyError.t()} | {:warning, String.t()}
  def validate_strategy(strategy, options \\ [])

  def validate_strategy(nil, _options) do
    {:error,
     StrategyError.exception(
       message: "Strategy cannot be nil",
       suggestions: ["Provide a valid strategy tuple {Module, :function, args} or {Module, opts}"]
     )}
  end

  # Validate MFA tuple strategy
  def validate_strategy({module, function, args}, options)
      when is_atom(module) and is_atom(function) and is_list(args) do
    debug_mode = Keyword.get(options, :debug, false)

    if debug_mode do
      IO.puts(
        "[DEBUG] Validating MFA strategy: #{inspect(module)}.#{function}/#{length(args) + 2}"
      )
    end

    with :ok <- validate_module_exists(module),
         :ok <- validate_function_exists(module, function, length(args) + 2),
         :ok <- validate_strategy_args(args) do
      check_strategy_warnings({module, function, args}, options)
    else
      {:error, reason} ->
        {:error,
         StrategyError.exception(
           message: reason,
           strategy: {module, function, args},
           suggestions: get_mfa_strategy_suggestions(module, function, args)
         )}
    end
  end

  # Validate Strategy behaviour
  def validate_strategy({module, opts}, options) when is_atom(module) and is_list(opts) do
    debug_mode = Keyword.get(options, :debug, false)

    if debug_mode do
      IO.puts(
        "[DEBUG] Validating Strategy behaviour: #{inspect(module)} with options #{inspect(opts)}"
      )
    end

    with :ok <- validate_module_exists(module),
         :ok <- validate_strategy_behaviour(module),
         :ok <- validate_strategy_options(module, opts) do
      check_strategy_warnings({module, opts}, options)
    else
      {:error, reason} ->
        {:error,
         StrategyError.exception(
           message: reason,
           strategy: {module, opts},
           suggestions: get_behaviour_strategy_suggestions(module, opts)
         )}
    end
  end

  def validate_strategy(strategy, _options) do
    {:error,
     StrategyError.exception(
       message: "Invalid strategy format: #{inspect(strategy)}",
       strategy: strategy,
       suggestions: [
         "Use MFA tuple format: {Module, :function, args}",
         "Use Strategy behaviour format: {Module, opts}",
         "Ensure all elements are properly typed"
       ]
     )}
  end

  @doc """
  Validates backtest options and detects potential issues.

  ## Examples

      iex> ExPostFacto.Validation.validate_options([starting_balance: 10000.0])
      :ok

      iex> ExPostFacto.Validation.validate_options([starting_balance: -1000.0])
      {:error, "Starting balance must be non-negative, got: -1000.0"}
  """
  @spec validate_options(keyword()) :: :ok | {:error, String.t()} | {:warning, String.t()}
  def validate_options(options) when is_list(options) do
    with :ok <- validate_starting_balance(options),
         :ok <- validate_boolean_options(options),
         :ok <- validate_numeric_options(options) do
      check_option_warnings(options)
    end
  end

  @doc """
  Checks for runtime warnings during backtest execution.

  This function analyzes backtest results and identifies potential issues
  that might affect performance or correctness.

  ## Examples

      iex> result = %ExPostFacto.Result{trades_count: 0, starting_balance: 10000.0}
      iex> ExPostFacto.Validation.check_runtime_warnings(result)
      {:warning, "Unusual win rate (0.0%) - verify strategy logic"}
  """
  @spec check_runtime_warnings(Result.t(), keyword()) :: :ok | {:warning, String.t()}
  def check_runtime_warnings(%Result{} = result, _options \\ []) do
    warnings = []

    warnings =
      warnings
      |> check_no_trades_warning(result)
      |> check_excessive_trades_warning(result)
      |> check_poor_performance_warning(result)
      |> check_high_drawdown_warning(result)
      |> check_unusual_patterns_warning(result)

    case warnings do
      [] -> :ok
      [warning | _] -> {:warning, warning}
    end
  end

  @doc """
  Provides detailed error context and debugging information.

  ## Examples

      iex> error = %ExPostFacto.Validation.ValidationError{
      ...>   message: "Invalid data",
      ...>   context: %{point_index: 5},
      ...>   suggestions: ["Check data source"]
      ...> }
      iex> ExPostFacto.Validation.format_error(error)
      "Invalid data\\n\\nContext: point_index: 5\\n\\nSuggestions:\\n  - Check data source"
  """
  @spec format_error(ValidationError.t() | StrategyError.t()) :: String.t()
  def format_error(%ValidationError{} = error) do
    context_str = format_context(error.context)
    suggestions_str = format_suggestions(error.suggestions)

    [error.message, context_str, suggestions_str]
    |> Enum.filter(&(not is_nil(&1) and &1 != ""))
    |> Enum.join("\n\n")
  end

  def format_error(%StrategyError{} = error) do
    strategy_str = if error.strategy, do: "Strategy: #{inspect(error.strategy)}", else: nil
    suggestions_str = format_suggestions(error.suggestions)
    debug_str = format_debug_info(error.debug_info)

    [error.message, strategy_str, suggestions_str, debug_str]
    |> Enum.filter(&(not is_nil(&1) and &1 != ""))
    |> Enum.join("\n\n")
  end

  # Private helper functions

  defp check_data_size(data, debug_mode) do
    size = length(data)

    cond do
      size == 0 ->
        {:error,
         ValidationError.exception(
           message: "Data cannot be empty",
           suggestions: ["Provide at least one data point", "Check data loading logic"]
         )}

      size < 10 ->
        if debug_mode do
          IO.puts(
            "[DEBUG] Warning: Very small dataset (#{size} points) - results may not be reliable"
          )
        end

        :ok

      size > 100_000 ->
        if debug_mode do
          IO.puts(
            "[DEBUG] Warning: Large dataset (#{size} points) - consider performance implications"
          )
        end

        :ok

      true ->
        :ok
    end
  end

  defp check_data_quality(data, debug_mode) do
    # Check for common data quality issues
    unique_count = data |> Enum.uniq() |> length()
    duplicate_ratio = (length(data) - unique_count) / length(data)

    if duplicate_ratio > 0.1 and debug_mode do
      IO.puts(
        "[DEBUG] Warning: High duplicate ratio (#{Float.round(duplicate_ratio * 100, 1)}%) detected"
      )
    end

    :ok
  end

  defp validate_individual_points(data, strict_mode, debug_mode) do
    data
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {point, index}, _acc ->
      case validate_data_point_enhanced(point, index, strict_mode, debug_mode) do
        :ok -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp validate_data_point_enhanced(point, index, strict_mode, debug_mode) do
    case point do
      point when is_map(point) ->
        with :ok <- validate_required_fields_enhanced(point, index),
             :ok <- validate_numeric_values_enhanced(point, index),
             :ok <- validate_ohlc_relationship_enhanced(point, index),
             :ok <- maybe_validate_strict_checks(point, index, strict_mode) do
          if debug_mode and rem(index, 1000) == 0 do
            IO.puts("[DEBUG] Validated #{index + 1} data points...")
          end

          :ok
        end

      _ ->
        {:error,
         ValidationError.exception(
           message: "Data point must be a map",
           context: %{point_index: index, point_type: typeof(point)},
           suggestions: [
             "Ensure all data points are maps with OHLC fields",
             "Check data parsing logic"
           ]
         )}
    end
  end

  defp validate_required_fields_enhanced(point, index) do
    required_fields = [:open, :high, :low, :close]
    alt_fields = [:o, :h, :l, :c]

    has_required = Enum.all?(required_fields, &Map.has_key?(point, &1))
    has_alt = Enum.all?(alt_fields, &Map.has_key?(point, &1))

    case {has_required, has_alt} do
      {true, _} ->
        :ok

      {false, true} ->
        :ok

      {false, false} ->
        missing_fields = required_fields |> Enum.reject(&Map.has_key?(point, &1))

        {:error,
         ValidationError.exception(
           message: "Missing required OHLC fields in data point #{index}",
           context: %{
             point_index: index,
             missing_fields: missing_fields,
             available_fields: Map.keys(point)
           },
           suggestions: [
             "Ensure all data points have open, high, low, close fields",
             "Alternative short form (o, h, l, c) is also supported",
             "Available fields: #{inspect(Map.keys(point))}"
           ]
         )}
    end
  end

  defp validate_numeric_values_enhanced(point, index) do
    values = [
      {get_field_value(point, :open, :o), "open"},
      {get_field_value(point, :high, :h), "high"},
      {get_field_value(point, :low, :l), "low"},
      {get_field_value(point, :close, :c), "close"}
    ]

    case find_invalid_value(values) do
      {nil, field} ->
        {:error,
         ValidationError.exception(
           message: "#{String.capitalize(field)} value cannot be nil in data point #{index}",
           context: %{point_index: index, field: field, point: point},
           suggestions: [
             "Remove data points with nil values",
             "Use data cleaning to filter invalid points"
           ]
         )}

      {:non_numeric, field, value} ->
        {:error,
         ValidationError.exception(
           message: "#{String.capitalize(field)} value must be numeric in data point #{index}",
           context: %{point_index: index, field: field, value: value, value_type: typeof(value)},
           suggestions: [
             "Ensure all OHLC values are numbers",
             "Check data parsing and type conversion"
           ]
         )}

      {:negative, field, value} ->
        {:error,
         ValidationError.exception(
           message:
             "#{String.capitalize(field)} value must be non-negative in data point #{index}",
           context: %{point_index: index, field: field, value: value},
           suggestions: ["Check data source for errors", "Remove or correct negative values"]
         )}

      :ok ->
        :ok
    end
  end

  defp validate_ohlc_relationship_enhanced(point, index) do
    high = get_field_value(point, :high, :h)
    low = get_field_value(point, :low, :l)
    open = get_field_value(point, :open, :o)
    close = get_field_value(point, :close, :c)

    cond do
      high < low ->
        {:error,
         ValidationError.exception(
           message: "Invalid OHLC relationship in data point #{index}: high < low",
           context: %{point_index: index, high: high, low: low},
           suggestions: ["Ensure high >= low for all data points", "Check data source for errors"]
         )}

      open > high ->
        {:error,
         ValidationError.exception(
           message: "Invalid OHLC relationship in data point #{index}: open > high",
           context: %{point_index: index, open: open, high: high},
           suggestions: ["Ensure open <= high for all data points", "Verify data integrity"]
         )}

      open < low ->
        {:error,
         ValidationError.exception(
           message: "Invalid OHLC relationship in data point #{index}: open < low",
           context: %{point_index: index, open: open, low: low},
           suggestions: ["Ensure open >= low for all data points", "Check data source"]
         )}

      close > high ->
        {:error,
         ValidationError.exception(
           message: "Invalid OHLC relationship in data point #{index}: close > high",
           context: %{point_index: index, close: close, high: high},
           suggestions: ["Ensure close <= high for all data points", "Verify data accuracy"]
         )}

      close < low ->
        {:error,
         ValidationError.exception(
           message: "Invalid OHLC relationship in data point #{index}: close < low",
           context: %{point_index: index, close: close, low: low},
           suggestions: ["Ensure close >= low for all data points", "Check data quality"]
         )}

      true ->
        :ok
    end
  end

  defp maybe_validate_strict_checks(_point, _index, false), do: :ok

  defp maybe_validate_strict_checks(point, index, true) do
    # Strict mode additional checks
    high = get_field_value(point, :high, :h)
    low = get_field_value(point, :low, :l)

    # Check for suspicious patterns
    range = high - low

    if range == 0 do
      {:error,
       ValidationError.exception(
         message: "Suspicious data in point #{index}: high equals low (no price movement)",
         context: %{point_index: index, high: high, low: low},
         suggestions: [
           "Verify if zero price movement is correct",
           "Consider using less strict validation"
         ]
       )}
    else
      :ok
    end
  end

  defp check_data_warnings(data, _context) do
    # Check for potential issues that warrant warnings
    avg_volume = calculate_average_volume(data)
    price_range = calculate_price_range(data)

    cond do
      is_nil(avg_volume) ->
        {:warning, "No volume data detected - some strategies may require volume information"}

      price_range[:coefficient_of_variation] > 2.0 ->
        {:warning, "High price volatility detected - results may be sensitive to outliers"}

      true ->
        :ok
    end
  end

  defp validate_module_exists(module) do
    case Code.ensure_loaded(module) do
      {:module, ^module} -> :ok
      {:error, _} -> {:error, "Module #{inspect(module)} does not exist"}
    end
  end

  defp validate_function_exists(module, function, arity) do
    if function_exported?(module, function, arity) do
      :ok
    else
      {:error, "Function #{inspect(module)}.#{function}/#{arity} does not exist"}
    end
  end

  defp validate_strategy_behaviour(module) do
    behaviours = module.module_info(:attributes) |> Keyword.get(:behaviour, [])

    if Strategy in behaviours do
      :ok
    else
      {:error, "Module #{inspect(module)} does not implement ExPostFacto.Strategy behaviour"}
    end
  end

  defp validate_strategy_args(args) when is_list(args), do: :ok
  defp validate_strategy_args(_), do: {:error, "Strategy arguments must be a list"}

  defp validate_strategy_options(module, opts) do
    # Check if module has option validation
    if function_exported?(module, :validate_options, 1) do
      case apply(module, :validate_options, [opts]) do
        :ok -> :ok
        {:error, reason} -> {:error, "Strategy option validation failed: #{reason}"}
      end
    else
      :ok
    end
  end

  defp validate_starting_balance(options) do
    case Keyword.get(options, :starting_balance) do
      nil -> :ok
      balance when is_number(balance) and balance >= 0 -> :ok
      balance -> {:error, "Starting balance must be non-negative, got: #{inspect(balance)}"}
    end
  end

  defp validate_boolean_options(options) do
    boolean_options = [:validate_data, :clean_data, :debug]

    Enum.find_value(boolean_options, :ok, fn option ->
      case Keyword.get(options, option) do
        nil -> nil
        value when is_boolean(value) -> nil
        value -> {:error, "Option #{option} must be boolean, got: #{inspect(value)}"}
      end
    end)
  end

  defp validate_numeric_options(options) do
    numeric_options = [:starting_balance]

    Enum.find_value(numeric_options, :ok, fn option ->
      case Keyword.get(options, option) do
        nil -> nil
        value when is_number(value) -> nil
        value -> {:error, "Option #{option} must be numeric, got: #{inspect(value)}"}
      end
    end)
  end

  defp check_option_warnings(options) do
    cond do
      Keyword.get(options, :validate_data) == false ->
        {:warning, "Data validation is disabled - proceed with caution"}

      Keyword.get(options, :starting_balance, 0) == 0 ->
        {:warning, "Starting balance is 0 - profit/loss calculations may not be meaningful"}

      true ->
        :ok
    end
  end

  defp check_strategy_warnings(strategy, options) do
    debug_mode = Keyword.get(options, :debug, false)

    case strategy do
      {_module, function, _args} when function in [:noop, :no_op] ->
        if debug_mode do
          IO.puts("[DEBUG] Warning: Using no-op strategy - no trades will be executed")
        end

        {:warning, "Using no-operation strategy - this is typically for testing only"}

      _ ->
        :ok
    end
  end

  # Warning check helpers
  defp check_no_trades_warning(warnings, %Result{trades_count: 0}) do
    ["No trades executed - strategy may be too conservative or data insufficient" | warnings]
  end

  defp check_no_trades_warning(warnings, _), do: warnings

  defp check_excessive_trades_warning(warnings, %Result{trades_count: count}) when count > 1000 do
    ["Excessive trading detected (#{count} trades) - consider transaction costs" | warnings]
  end

  defp check_excessive_trades_warning(warnings, _), do: warnings

  defp check_poor_performance_warning(warnings, %Result{total_profit_and_loss: pnl})
       when pnl < 0 do
    ["Negative total return - strategy may need optimization" | warnings]
  end

  defp check_poor_performance_warning(warnings, _), do: warnings

  defp check_high_drawdown_warning(warnings, %Result{max_draw_down_percentage: dd})
       when dd < -20.0 do
    ["High maximum drawdown (#{Float.round(dd, 1)}%) - consider risk management" | warnings]
  end

  defp check_high_drawdown_warning(warnings, _), do: warnings

  defp check_unusual_patterns_warning(warnings, %Result{win_rate: wr})
       when wr > 95.0 or wr < 5.0 do
    ["Unusual win rate (#{Float.round(wr, 1)}%) - verify strategy logic" | warnings]
  end

  defp check_unusual_patterns_warning(warnings, _), do: warnings

  # Helper functions
  defp find_invalid_value(values) do
    Enum.find_value(values, :ok, fn {value, field} ->
      cond do
        is_nil(value) -> {nil, field}
        not is_number(value) -> {:non_numeric, field, value}
        value < 0 -> {:negative, field, value}
        true -> nil
      end
    end)
  end

  defp get_field_value(point, primary_key, alt_key) do
    Map.get(point, primary_key) || Map.get(point, alt_key)
  end

  defp calculate_average_volume(data) do
    volumes = Enum.map(data, &(Map.get(&1, :volume) || Map.get(&1, :v)))
    valid_volumes = Enum.filter(volumes, &(not is_nil(&1) and is_number(&1)))

    if Enum.empty?(valid_volumes) do
      nil
    else
      Enum.sum(valid_volumes) / length(valid_volumes)
    end
  end

  defp calculate_price_range(data) do
    closes = Enum.map(data, &get_field_value(&1, :close, :c))
    valid_closes = Enum.filter(closes, &(not is_nil(&1) and is_number(&1)))

    if length(valid_closes) > 1 do
      mean = Enum.sum(valid_closes) / length(valid_closes)
      variance = Enum.sum(Enum.map(valid_closes, &:math.pow(&1 - mean, 2))) / length(valid_closes)
      std_dev = :math.sqrt(variance)

      %{
        mean: mean,
        std_dev: std_dev,
        coefficient_of_variation: if(mean != 0, do: std_dev / mean, else: 0)
      }
    else
      %{mean: 0, std_dev: 0, coefficient_of_variation: 0}
    end
  end

  defp get_mfa_strategy_suggestions(module, function, args) do
    [
      "Check module name spelling: #{inspect(module)}",
      "Ensure module is compiled and available",
      "Verify function exists: #{function}/#{length(args) + 2}",
      "Strategy function should accept (market_data, result, ...args)"
    ]
  end

  defp get_behaviour_strategy_suggestions(_module, opts) do
    [
      "Ensure module implements ExPostFacto.Strategy behaviour",
      "Check that @behaviour ExPostFacto.Strategy is declared",
      "Verify all required callbacks are implemented",
      "Validate strategy options: #{inspect(opts)}"
    ]
  end

  defp format_context(context) when map_size(context) == 0, do: nil

  defp format_context(context) do
    "Context: " <> Enum.map_join(context, ", ", fn {k, v} -> "#{k}: #{inspect(v)}" end)
  end

  defp format_suggestions([]), do: nil

  defp format_suggestions(suggestions) do
    "Suggestions:\n" <> Enum.map_join(suggestions, "\n", &("  - " <> &1))
  end

  defp format_debug_info(debug_info) when map_size(debug_info) == 0, do: nil

  defp format_debug_info(debug_info) do
    "Debug Info: " <> Enum.map_join(debug_info, ", ", fn {k, v} -> "#{k}: #{inspect(v)}" end)
  end

  defp typeof(value) do
    cond do
      is_atom(value) -> :atom
      is_binary(value) -> :string
      is_integer(value) -> :integer
      is_float(value) -> :float
      is_list(value) -> :list
      is_map(value) -> :map
      is_tuple(value) -> :tuple
      true -> :unknown
    end
  end
end
