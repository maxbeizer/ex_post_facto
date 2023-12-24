defmodule ExPostFacto.TradeStats.CompilePairs do
  @moduledoc """
  Given a list of data points, group the enter and exit points into pairs.
  """
  alias ExPostFacto.{
    DataPoint,
    Result
  }

  alias ExPostFacto.TradeStats.TradePair

  @doc """
  Given a list of data points, group the enter and exit points into pairs. So,
  match the :close_buy with the closest :buy and :close_sell with the closest
  :sell.
  """
  @spec call!(result :: %Result{}) :: %Result{} | no_return()
  def call!(%{data_points: []} = result), do: result
  def call!(%{data_points: [_single_data_point]} = result), do: result

  def call!(%{data_points: [head | rest]} = result) do
    trade_pairs = build_pair_list(rest, head, [])

    trade_pairs_with_running_balance =
      calcaulate_running_balance(trade_pairs, result.starting_balance)

    %{result | trade_pairs: trade_pairs_with_running_balance}
  end

  defp calcaulate_running_balance(pairs, balance) do
    pairs
    |> seed_balance(balance)
    |> build_trade_pair([])
  end

  defp build_trade_pair([{exit_point, enter_point, balance}], output) do
    [TradePair.new(exit_point, enter_point, balance) | output]
  end

  defp build_trade_pair([{exit_point, enter_point}], output) do
    %{balance: balance} = hd(output)

    [TradePair.new(exit_point, enter_point, balance) | output]
  end

  defp build_trade_pair([{exit_point, enter_point, balance} | rest], []) do
    build_trade_pair(rest, [TradePair.new(exit_point, enter_point, balance)])
  end

  defp build_trade_pair([current | rest], output) do
    %{balance: balance} = hd(output)
    {exit_point, enter_point} = current

    build_trade_pair(rest, [TradePair.new(exit_point, enter_point, balance) | output])
  end

  defp seed_balance([{exit_point, enter_point} | rest], balance) do
    [{exit_point, enter_point, balance} | rest]
  end

  @spec build_pair_list(
          data_points :: [%DataPoint{}],
          head :: %DataPoint{},
          pairs :: [{%DataPoint{}, %DataPoint{}}]
        ) :: [{%DataPoint{}, %DataPoint{}}]
  defp build_pair_list([], _head, pairs), do: pairs

  defp build_pair_list([head | rest], previous, pairs) do
    cond do
      previous.action == :close_buy and head.action == :buy ->
        colllect_pairs(rest, [{previous, head} | pairs])

      previous.action == :close_sell and head.action == :sell ->
        colllect_pairs(rest, [{previous, head} | pairs])

      true ->
        build_pair_list(rest, head, pairs)
    end
  end

  @spec colllect_pairs(
          data_points :: [%DataPoint{}],
          pairs :: [{%DataPoint{}, %DataPoint{}}]
        ) :: [{%DataPoint{}, %DataPoint{}}]
  defp colllect_pairs([] = _rest, pairs), do: pairs
  defp colllect_pairs([_single_item] = _rest, pairs), do: pairs

  defp colllect_pairs([next_head | next_rest], pairs) do
    build_pair_list(next_rest, next_head, pairs)
  end
end
