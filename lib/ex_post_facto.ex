defmodule ExPostFacto do
  @moduledoc """
  ExPostFacto is a library for backtesting trading strategies. It is still under
  development but takes a lot of inspiration from various Python libraries in
  this space.
  """

  @doc """
  The main entry point of the library. This function takes in a list of HLOC
  data and function that will be used to generate buy and sell signals. The
  function should return `:buy`, `:sell`, `:close` when called. Options may also
  be passed in, optionns are TBD.

  The function returns an ok or error tuple. In an ok tuple, the data, and a
  results struct are returned. In an error tuple, a string is returned with the
  error message.

  ## Examples

      iex> ExPostFacto.backtest(nil, fn _ -> :buy end)
      {:error, "data cannot be nil"}

      iex> ExPostFacto.backtest([], nil)
      {:error, "strategy cannot be nil"}

      iex> ExPostFacto.backtest([%{high: 1.0, low: 0.0, open: 0.25, close: 0.75}], fn _ -> :buy end)
      {:ok, %{data: [%{high: 1.0, low: 0.0, open: 0.25, close: 0.75}]}}
  """
  @spec backtest(
          data :: list(),
          strategy :: function(),
          options :: keyword()
        ) ::
          {:ok, map()} | {:error, String.t()}
  def backtest(data, strategy, options \\ [])
  def backtest(nil, _strategy, _options), do: {:error, "data cannot be nil"}
  def backtest(_data, nil, _options), do: {:error, "strategy cannot be nil"}

  def backtest(data, _strategy, _options) do
    {:ok, %{data: data}}
  end
end
