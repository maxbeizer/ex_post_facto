defmodule ExPostFacto.TradeStats.CompilePairs do
  @moduledoc """
  Given a list of data points, group the enter and exit points into pairs.
  """
  alias ExPostFacto.{
    DataPoint,
    Result
  }

  alias ExPostFacto.TradeStats.TotalProfitAndLoss

  @doc """
  Given a list of data points, group the enter and exit points into pairs. So,
  match the :close_buy with the closest :buy and :close_sell with the closest
  :sell.
  """
  @spec call!(result :: %Result{}) :: %Result{} | no_return()
  def call!(%{data_points: []} = result), do: result
  def call!(%{data_points: [_single_data_point]} = result), do: result

  def call!(%{data_points: [head | rest]} = result) do
    trade_pairs = do_call(rest, head, [])

    trade_pairs_with_running_balance =
      calcaulate_running_balance(trade_pairs, result.starting_balance)

    %{result | trade_pairs: trade_pairs_with_running_balance}
  end

  defp calcaulate_running_balance(pairs, balance) do
    # require IEx
    # IEx.pry()

    pairs
    # |> Enum.reverse()
    |> seed_balance(balance)
    |> do_it([])
  end

  defp do_it([{exit_point, enter_point, balance}], output) do
    [
      {exit_point, enter_point, TotalProfitAndLoss.calculate!([exit_point, enter_point], balance)}
      | output
    ]
  end

  defp do_it([{exit_point, enter_point}], output) do
    {_, _, balance} = hd(output)

    [
      {exit_point, enter_point, TotalProfitAndLoss.calculate!([exit_point, enter_point], balance)}
      | output
    ]
  end

  defp do_it([{exit_point, enter_point, balance} | rest], []) do
    do_it(
      rest,
      [
        {exit_point, enter_point,
         TotalProfitAndLoss.calculate!([exit_point, enter_point], balance)}
      ]
    )
  end

  defp do_it([current | rest], output) do
    {_exit_point, _enter_point, balance} = hd(output)
    {exit_point, enter_point} = current

    do_it(
      rest,
      [
        {exit_point, enter_point,
         TotalProfitAndLoss.calculate!([exit_point, enter_point], balance)}
        | output
      ]
    )
  end

  defp seed_balance([{exit_point, enter_point} | rest], balance) do
    [{exit_point, enter_point, balance} | rest]
  end

  @spec do_call(
          data_points :: [%DataPoint{}],
          head :: %DataPoint{},
          pairs :: [{%DataPoint{}, %DataPoint{}}]
        ) :: [{%DataPoint{}, %DataPoint{}}]
  defp do_call([], _head, pairs), do: pairs

  defp do_call([head | rest], previous, pairs) do
    cond do
      previous.action == :close_buy and head.action == :buy ->
        colllect_pairs(rest, [{previous, head} | pairs])

      previous.action == :close_sell and head.action == :sell ->
        colllect_pairs(rest, [{previous, head} | pairs])

      true ->
        do_call(rest, head, pairs)
    end
  end

  @spec colllect_pairs(
          data_points :: [%DataPoint{}],
          pairs :: [{%DataPoint{}, %DataPoint{}}]
        ) :: [{%DataPoint{}, %DataPoint{}}]
  defp colllect_pairs([] = _rest, pairs), do: pairs
  defp colllect_pairs([_single_item] = _rest, pairs), do: pairs

  defp colllect_pairs([next_head | next_rest], pairs) do
    do_call(next_rest, next_head, pairs)
  end
end
