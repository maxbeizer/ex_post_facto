defmodule TradeStats.TradePercentageTest do
  use ExUnit.Case, async: true

  alias ExPostFacto.Result
  alias ExPostFacto.TradeStats.TradePercentage

  test "best!/1 when on only one data point, returns the percentage" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 100.0}, :buy)
      |> Result.add_data_point(1, %{open: 200.0}, :close_buy)
      |> Result.compile()

    percentage = TradePercentage.best!(result)
    assert 100.0 == percentage
  end

  test "best!/1 when multiple data points, returns the percentage" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 100.0}, :buy)
      |> Result.add_data_point(1, %{open: 200.0}, :close_buy)
      |> Result.add_data_point(2, %{open: 100.0}, :buy)
      |> Result.add_data_point(3, %{open: 100.0}, :close_buy)
      |> Result.compile()

    percentage = TradePercentage.best!(result)
    assert 100.0 == percentage
  end

  test "best!/1 when no data points, returns 0.0" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.compile()

    percentage = TradePercentage.best!(result)
    assert 0.0 == percentage
  end

  test "best!/1 returns non-100 percentages" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 100.0}, :buy)
      |> Result.add_data_point(1, %{open: 101.0}, :close_buy)
      |> Result.compile()

    percentage = TradePercentage.best!(result)
    assert 1.0 == percentage
  end

  test "best!/1 returns percentage on sells as well" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 101.0}, :sell)
      |> Result.add_data_point(1, %{open: 100.0}, :close_sell)
      |> Result.compile()

    percentage = TradePercentage.best!(result)
    assert 1.0 == percentage
  end

  test "best!/1 returns negative percentage if only single loss" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 100.0}, :sell)
      |> Result.add_data_point(1, %{open: 101.0}, :close_sell)
      |> Result.compile()

    percentage = TradePercentage.best!(result)
    assert -1.0 == percentage
  end

  test "best!/1 returns negative percentage if only losses" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 100.0}, :sell)
      |> Result.add_data_point(1, %{open: 101.0}, :close_sell)
      |> Result.add_data_point(2, %{open: 100.0}, :sell)
      |> Result.add_data_point(3, %{open: 150.0}, :close_sell)
      |> Result.compile()

    percentage = TradePercentage.best!(result)
    assert -1.0 == percentage
  end

  test "worst!/1 when on only one data point, returns the percentage" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 100.0}, :buy)
      |> Result.add_data_point(1, %{open: 200.0}, :close_buy)
      |> Result.compile()

    percentage = TradePercentage.worst!(result)
    assert 100.0 == percentage
  end

  test "worst!/1 when multiple data points, returns the percentage" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 100.0}, :buy)
      |> Result.add_data_point(1, %{open: 200.0}, :close_buy)
      |> Result.add_data_point(2, %{open: 100.0}, :buy)
      |> Result.add_data_point(3, %{open: 100.0}, :close_buy)
      |> Result.compile()

    percentage = TradePercentage.worst!(result)
    assert 0.0 == percentage
  end

  test "worst!/1 when no data points, returns 0.0" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.compile()

    percentage = TradePercentage.worst!(result)
    assert 0.0 == percentage
  end

  test "worst!/1 returns non-100 percentages" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 100.0}, :buy)
      |> Result.add_data_point(1, %{open: 101.0}, :close_buy)
      |> Result.compile()

    percentage = TradePercentage.worst!(result)
    assert 1.0 == percentage
  end

  test "worst!/1 returns percentage on sells as well" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 101.0}, :sell)
      |> Result.add_data_point(1, %{open: 100.0}, :close_sell)
      |> Result.compile()

    percentage = TradePercentage.worst!(result)
    assert 1.0 == percentage
  end

  test "worst!/1 returns negative percentage if only single loss" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 100.0}, :sell)
      |> Result.add_data_point(1, %{open: 101.0}, :close_sell)
      |> Result.compile()

    percentage = TradePercentage.worst!(result)
    assert -1.0 == percentage
  end

  test "worst!/1 returns negative percentage if only losses" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 100.0}, :sell)
      |> Result.add_data_point(1, %{open: 150.0}, :close_sell)
      |> Result.add_data_point(2, %{open: 100.0}, :sell)
      |> Result.add_data_point(3, %{open: 150.0}, :close_sell)
      |> Result.compile()

    percentage = TradePercentage.worst!(result)
    # 100 - 50 = 50 - 50 = 0 -> -100.0
    assert -100.0 == percentage
  end

  test "average!/1 when on only one data point, returns the percentage" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 100.0}, :buy)
      |> Result.add_data_point(1, %{open: 200.0}, :close_buy)
      |> Result.compile()

    percentage = TradePercentage.average!(result)
    assert 100.0 == percentage
  end

  test "average!/1 when multiple data points, returns the percentage" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 100.0}, :buy)
      |> Result.add_data_point(1, %{open: 200.0}, :close_buy)
      |> Result.add_data_point(2, %{open: 100.0}, :buy)
      |> Result.add_data_point(3, %{open: 100.0}, :close_buy)
      |> Result.compile()

    percentage = TradePercentage.average!(result)
    # 100/200 = 0.5 -> 50.0
    assert 50.0 == percentage
  end

  test "average!/1 when no data points, returns 0.0" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.compile()

    percentage = TradePercentage.average!(result)
    assert 0.0 == percentage
  end

  test "average!/1 returns non-100 percentages" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 100.0}, :buy)
      |> Result.add_data_point(1, %{open: 101.0}, :close_buy)
      |> Result.compile()

    percentage = TradePercentage.average!(result)
    assert 1.0 == percentage
  end

  test "average!/1 returns percentage on sells as well" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 101.0}, :sell)
      |> Result.add_data_point(1, %{open: 100.0}, :close_sell)
      |> Result.compile()

    percentage = TradePercentage.average!(result)
    assert 1.0 == percentage
  end

  test "average!/1 returns negative percentage if only single loss" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 100.0}, :sell)
      |> Result.add_data_point(1, %{open: 101.0}, :close_sell)
      |> Result.compile()

    percentage = TradePercentage.average!(result)
    assert -1.0 == percentage
  end

  test "average!/1 returns negative percentage if only losses" do
    result =
      Result.new(starting_balance: 100.0)
      |> Result.add_data_point(0, %{open: 100.0}, :sell)
      |> Result.add_data_point(1, %{open: 150.0}, :close_sell)
      |> Result.add_data_point(2, %{open: 100.0}, :sell)
      |> Result.add_data_point(3, %{open: 150.0}, :close_sell)
      |> Result.compile()

    percentage = TradePercentage.average!(result)
    # -50 + -50 = -100 -> -100/2 = -50.0
    assert -50.0 == percentage
  end
end
