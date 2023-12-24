defmodule TradeStats.CompilePairsTest do
  use ExUnit.Case, async: true

  alias ExPostFacto.{
    Result
  }

  alias ExPostFacto.TradeStats.CompilePairs

  test "builds a list of trade pairs from data points" do
    result =
      Result.new()
      |> Result.add_data_point(0, %{open: 100.0}, :buy)
      |> Result.add_data_point(1, %{open: 200.0}, :close_buy)

    assert 1 == length(CompilePairs.call!(result).trade_pairs)
  end

  test "builds a list of trade pairs from multiple data points" do
    result =
      Result.new()
      |> Result.add_data_point(0, %{open: 100.0}, :buy)
      |> Result.add_data_point(1, %{open: 200.0}, :close_buy)
      |> Result.add_data_point(2, %{open: 100.0}, :buy)
      |> Result.add_data_point(3, %{open: 200.0}, :close_buy)

    assert 2 == length(CompilePairs.call!(result).trade_pairs)
  end

  test "keeps track of the running balance" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 100.0}, :buy)
      |> Result.add_data_point(1, %{open: 200.0}, :close_buy)

    [%{balance: balance}] = CompilePairs.call!(result).trade_pairs
    assert 200.0 == balance
  end

  test "keeps track of the running balance with multiple data points" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 100.0}, :buy)
      |> Result.add_data_point(1, %{open: 200.0}, :close_buy)
      |> Result.add_data_point(2, %{open: 300.0}, :buy)
      |> Result.add_data_point(3, %{open: 500.0}, :close_buy)

    pairs = CompilePairs.call!(result).trade_pairs
    [%{balance: balance} | _] = pairs
    # 100 (start) + 100 (first pair) + 200 (second pair) == 400
    assert 400.0 == balance
  end

  test "keeps the descending index order of trade pairs" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 100.0}, :buy)
      |> Result.add_data_point(1, %{open: 200.0}, :close_buy)
      |> Result.add_data_point(2, %{open: 300.0}, :buy)
      |> Result.add_data_point(3, %{open: 400.0}, :close_buy)

    pairs = CompilePairs.call!(result).trade_pairs
    [%{exit_point: exit_point} | _] = pairs
    assert 3 == exit_point.index
  end
end
