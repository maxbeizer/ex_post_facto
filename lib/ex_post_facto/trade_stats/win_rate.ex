defmodule ExPostFacto.TradeStats.WinRate do
  @moduledoc """
  Calculates the win rate for a result based on data points
  """
  alias ExPostFacto.{
    DataPoint,
    Result
  }

  @spec calculate!(result :: %Result{}) :: float() | no_return()
  def calculate!(%{trades_count: 0}), do: 0.0

  def calculate!(%{trades_count: trades_count, data_points: data_points}) do
    win_count =
      data_points
      |> find_pairs()
      |> Enum.reduce(0, &calculate_win_count/2)

    win_count / trades_count * 100.0
  end

  @spec find_pairs(data_points :: [%DataPoint{}]) :: [{%DataPoint{}, %DataPoint{}}]
  defp find_pairs([]), do: []
  defp find_pairs([_single_data_point]), do: []

  defp find_pairs([head | rest]) do
    do_find_pairs(rest, head, [])
  end

  @spec do_find_pairs(
          data_points :: [%DataPoint{}],
          head :: %DataPoint{},
          pairs :: [{%DataPoint{}, %DataPoint{}}]
        ) :: [{%DataPoint{}, %DataPoint{}}]
  defp do_find_pairs([], _head, pairs), do: pairs

  defp do_find_pairs([head | rest], previous, pairs) do
    cond do
      previous.action == :close_buy and head.action == :buy ->
        colllect_pairs(rest, [{previous, head} | pairs])

      previous.action == :close_sell and head.action == :sell ->
        colllect_pairs(rest, [{previous, head} | pairs])

      true ->
        do_find_pairs(rest, head, pairs)
    end
  end

  @spec colllect_pairs(
          data_points :: [%DataPoint{}],
          pairs :: [{%DataPoint{}, %DataPoint{}}]
        ) :: [{%DataPoint{}, %DataPoint{}}]
  defp colllect_pairs([] = _rest, pairs), do: pairs
  defp colllect_pairs([_sing_item] = _rest, pairs), do: pairs

  defp colllect_pairs([next_head | next_rest], pairs) do
    do_find_pairs(next_rest, next_head, pairs)
  end

  @spec calculate_win_count(
          pair :: {%DataPoint{}, %DataPoint{}},
          win_count :: non_neg_integer()
        ) ::
          non_neg_integer()
  defp calculate_win_count(
         {%{datum: %{close: exit_price}}, %{datum: %{close: enter_price}, action: :buy}},
         win_count
       ) do
    cond do
      exit_price > enter_price ->
        win_count + 1

      exit_price < enter_price ->
        win_count

      exit_price == enter_price ->
        win_count
    end
  end

  defp calculate_win_count(
         {%{datum: %{close: exit_price}}, %{datum: %{close: enter_price}, action: :sell}},
         win_count
       ) do
    cond do
      exit_price < enter_price ->
        win_count + 1

      exit_price > enter_price ->
        win_count

      exit_price == enter_price ->
        win_count
    end
  end
end
