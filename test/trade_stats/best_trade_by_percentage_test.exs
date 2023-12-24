defmodule TradeStats.BestTradeByPercentageTest do
  use ExUnit.Case, async: true

  alias ExPostFacto.Result
  alias ExPostFacto.TradeStats.BestTradeByPercentage

  test "when on only one data point, returns the percentage" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 100.0}, :buy)
      |> Result.add_data_point(1, %{open: 200.0}, :close_buy)
      |> Result.compile()

    percentage = BestTradeByPercentage.calculate!(result)
    assert 100.0 = percentage
  end

  test "when multiple data points, returns the percentage" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 100.0}, :buy)
      |> Result.add_data_point(1, %{open: 200.0}, :close_buy)
      |> Result.add_data_point(2, %{open: 100.0}, :buy)
      |> Result.add_data_point(3, %{open: 100.0}, :close_buy)
      |> Result.compile()

    percentage = BestTradeByPercentage.calculate!(result)
    assert 100.0 = percentage
  end

  test "when no data points, returns 0.0" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.compile()

    percentage = BestTradeByPercentage.calculate!(result)
    assert 0.0 = percentage
  end

  test "returns non-100 percentages" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 100.0}, :buy)
      |> Result.add_data_point(1, %{open: 101.0}, :close_buy)
      |> Result.compile()

    percentage = BestTradeByPercentage.calculate!(result)
    assert 1.0 = percentage
  end

  test "returns percentage on sells as well" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 101.0}, :sell)
      |> Result.add_data_point(1, %{open: 100.0}, :close_sell)
      |> Result.compile()

    percentage = BestTradeByPercentage.calculate!(result)
    assert 1.0 = percentage
  end

  test "returns negative percentage if only single loss" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 100.0}, :sell)
      |> Result.add_data_point(1, %{open: 101.0}, :close_sell)
      |> Result.compile()

    percentage = BestTradeByPercentage.calculate!(result)
    assert -1.0 = percentage
  end

  test "returns negative percentage if only losses" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 100.0}, :sell)
      |> Result.add_data_point(1, %{open: 101.0}, :close_sell)
      |> Result.add_data_point(2, %{open: 100.0}, :sell)
      |> Result.add_data_point(3, %{open: 150.0}, :close_sell)
      |> Result.compile()

    percentage = BestTradeByPercentage.calculate!(result)
    assert -1.0 = percentage
  end
end
