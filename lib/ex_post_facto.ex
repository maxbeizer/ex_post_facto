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

      # This would be used with Strategy behaviour modules
      # iex> ExPostFacto.backtest!(data, {MyStrategy, [param: 10]})
  """
  @spec backtest!(
          data :: [DataPoint.t()],
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

      # This would be used with Strategy behaviour modules
      # iex> ExPostFacto.backtest(data, {MyStrategy, [param: 10]})
  """
  @spec backtest(
          data :: [DataPoint.t()],
          strategy :: strategy(),
          options :: keyword()
        ) ::
          {:ok, Output.t()} | {:error, String.t()}
  def backtest(data, strategy, options \\ [])
  def backtest(nil, _strategy, _options), do: {:error, "data cannot be nil"}
  def backtest([], _, _options), do: {:error, "data cannot be empty"}
  def backtest(_data, nil, _options), do: {:error, "strategy cannot be nil"}

  def backtest(data, strategy, options) do
    # Initialize strategy if it's a behaviour-based strategy
    case strategy do
      {module, opts} when is_list(opts) ->
        case initialize_strategy_behaviour(module, opts) do
          {:ok, strategy_state} ->
            backtest_with_behaviour(data, {module, strategy_state}, options)

          {:error, reason} ->
            {:error, "strategy initialization failed: #{inspect(reason)}"}
        end

      {_module, _function, _args} ->
        backtest_with_mfa(data, strategy, options)

      _ ->
        {:error, "invalid strategy format"}
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
end
