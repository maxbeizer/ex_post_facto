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
    Result
  }

  @actions [:buy, :sell, :close]
  @type action :: :buy | :sell | :close
  @type module_function_arguments :: {module :: atom(), function :: atom(), args :: list()}

  defmodule BacktestError do
    defexception message: "unable to run backtest"
  end

  @doc """
  The main entry point of the library. This function takes in a list of HLOC
  data and function that will be used to generate buy and sell signals. The
  function should return `:buy`, `:sell`, `:close` when called. Options may also
  be passed in, optionns are TBD.

  The function returns output struct or raises an error

  ## Examples

      iex> ExPostFacto.backtest!(nil, {Foo, :bar, []})
      ** (ExPostFacto.BacktestError) data cannot be nil

      iex> ExPostFacto.backtest!([], nil)
      ** (ExPostFacto.BacktestError) strategy cannot be nil

      iex> ExPostFacto.backtest!([], {Noop, :noop, []})
      %ExPostFacto.Output{data: [], result: %ExPostFacto.Result{data_points: [], total_profit_and_loss: 0.0, max_draw_down: 0.0}, strategy: {Noop, :noop, []}}
  """
  @spec backtest!(
          data :: [DataPoint.t()],
          strategy :: module_function_arguments(),
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
  HLOC data and function that will be used to generate buy and sell signals. The
  function should return `:buy`, `:sell`, `:close` when called. Options may also
  be passed in, optionns are TBD.

  The function returns an ok or error tuple. In an ok tuple, the data, and a
  results struct are returned. In an error tuple, a string is returned with the
  error message.

  ## Examples

      iex> ExPostFacto.backtest(nil, {Foo, :bar, []})
      {:error, "data cannot be nil"}

      iex> ExPostFacto.backtest([], nil)
      {:error, "strategy cannot be nil"}

      iex> ExPostFacto.backtest([], {Noop, :noop, []})
      {:ok, %ExPostFacto.Output{data: [], result: %ExPostFacto.Result{data_points: [], total_profit_and_loss: 0.0, max_draw_down: 0.0}, strategy: {Noop, :noop, []}}}
  """
  @spec backtest(
          data :: [DataPoint.t()],
          strategy :: module_function_arguments(),
          options :: keyword()
        ) ::
          {:ok, Output.t()} | {:error, String.t()}
  def backtest(data, strategy, options \\ [])
  def backtest(nil, _strategy, _options), do: {:error, "data cannot be nil"}
  def backtest(_data, nil, _options), do: {:error, "strategy cannot be nil"}

  def backtest(data, strategy, options) do
    result = build_initial_result(options)

    result =
      data
      |> Enum.map(&InputData.munge/1)
      |> Enum.with_index(fn datum, index -> {index, datum} end)
      |> Enum.reduce(result, &apply_strategy(&1, &2, strategy))
      |> Result.compile(options)

    {:ok, Output.new(data, strategy, result)}
  end

  @spec apply_strategy(
          {index :: integer(), datum :: map()},
          result :: Result.t(),
          strategy :: module_function_arguments()
        ) :: Result.t()
  defp apply_strategy({index, datum}, result, {m, f, _a}) do
    action = apply(m, f, [datum])

    cond do
      action in @actions ->
        Result.add_data_point(result, index, datum, action)

      true ->
        result
    end
  end

  @spec build_initial_result(options :: keyword()) :: Result.t()
  defp build_initial_result(options) do
    starting_balance = Keyword.get(options, :starting_balance, 0.0)
    Result.new(starting_balance)
  end
end
