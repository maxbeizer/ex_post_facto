defmodule ExPostFacto do
  @moduledoc """
  ExPostFacto is a library for backtesting trading strategies. It is still under
  development but takes a lot of inspiration from various Python libraries in
  this space.
  """

  alias ExPostFacto.{
    Output,
    Result
  }

  @actions [:buy, :sell, :close]

  @doc """
  The main entry point of the library. This function takes in a list of HLOC
  data and function that will be used to generate buy and sell signals. The
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
          data :: list(),
          strategy :: mfa(),
          options :: keyword()
        ) ::
          {:ok, map()} | {:error, String.t()}
  def backtest(data, strategy, options \\ [])
  def backtest(nil, _strategy, _options), do: {:error, "data cannot be nil"}
  def backtest(_data, nil, _options), do: {:error, "strategy cannot be nil"}

  def backtest(data, strategy, _options) do
    result = Result.new()

    result =
      data
      |> Enum.with_index(fn datum, index -> {index, datum} end)
      |> Enum.reduce(result, &apply_strategy(&1, &2, strategy))

    {:ok, Output.new(data, strategy, result)}
  end

  @spec apply_strategy(
          {index :: integer(), datum :: map()},
          result :: Result.t(),
          strategy :: mfa()
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
end
