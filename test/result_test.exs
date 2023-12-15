defmodule ExPostFactoResultTest do
  use ExUnit.Case, async: true
  doctest ExPostFacto.Result

  alias ExPostFacto.{
    DataPoint,
    InputData,
    Result
  }

  test "new/1 returns a result struct without options" do
    assert %Result{} = Result.new()
  end

  test "new/1 sets a default starting balance of 0.0" do
    assert %{starting_balance: 0.0} = Result.new()
  end

  test "new/1 allows the passing of a starting balance as a KW options" do
    assert %{starting_balance: 100.0} = Result.new(starting_balance: 100.0)
  end

  test "new/1 allows the passing of a start_date" do
    assert %{start_date: "2018-01-01"} = Result.new(start_date: "2018-01-01")
  end

  test "new/1 allows the passing of a end_date" do
    assert %{end_date: "2018-01-01"} = Result.new(end_date: "2018-01-01")
  end

  test "new/1 calculates the duration if start and end are passed in" do
    assert %{duration: 1} = Result.new(start_date: "2018-01-01", end_date: "2018-01-02")
  end

  test "new/1 returns nil when no start passed in" do
    assert %{duration: nil} = Result.new(end_date: "2018-01-02")
  end

  test "new/1 returns nil when no end passed in" do
    assert %{duration: nil} = Result.new(start_date: "2018-01-01")
  end

  test "new/1 calculates the duration with date times which is zero for less than a day" do
    assert %{duration: 0} =
             Result.new(
               start_date: "2023-12-15T22:15:27.211832Z",
               end_date: "2023-12-15T23:15:27.211832Z"
             )
  end

  test "new/1 calculates the duration with date times on a daily magnitude" do
    assert %{duration: 14} =
             Result.new(
               start_date: "2023-12-01T22:15:27.211832Z",
               end_date: "2023-12-15T22:15:27.211832Z"
             )
  end

  test "new/1 defaults start and end to nil" do
    assert %{start_date: nil, end_date: nil} = Result.new()
  end

  test "counts the number of closed trades when all closed" do
    data_points = [
      DataPoint.new(InputData.munge(%{h: 100.0, l: 50.0, o: 75.0, c: 85.0}), :buy, 2)
    ]

    result =
      %Result{data_points: data_points, is_position_open: true}
      |> Result.add_data_point(3, %{}, :close)

    assert 1 == result.trades_count
  end

  test "counts the number of closed trades (multiple) when all closed" do
    data_points = [
      DataPoint.new(InputData.munge(%{h: 100.0, l: 50.0, o: 75.0, c: 85.0}), :buy, 2),
      DataPoint.new(InputData.munge(%{h: 100.0, l: 50.0, o: 75.0, c: 85.0}), :close, 1),
      DataPoint.new(InputData.munge(%{h: 100.0, l: 50.0, o: 75.0, c: 85.0}), :buy, 0)
    ]

    # start with one trade count from the data above
    result =
      %Result{data_points: data_points, is_position_open: true, trades_count: 1}
      |> Result.add_data_point(3, %{}, :close)

    assert 2 == result.trades_count
  end

  test "counts the number of closed trades ignores open trades" do
    data_points = []

    result =
      %Result{data_points: data_points, is_position_open: false}
      # only one open buy
      |> Result.add_data_point(3, %{}, :buy)

    assert 0 == result.trades_count
  end

  test "compile/2 calculates total profit and loss when zero data points" do
    result = %Result{data_points: [], is_position_open: false, starting_balance: 0.0}

    assert Result.compile(result, []) == %Result{
             data_points: [],
             is_position_open: false,
             starting_balance: 0.0,
             total_profit_and_loss: 0.0
           }
  end

  test "compile/2 calculates total profit when data points exist with buy" do
    data_points = [
      DataPoint.new(InputData.munge(%{h: 100.0, l: 50.0, o: 75.0, c: 85.0}), :close, 1),
      DataPoint.new(InputData.munge(%{h: 100.0, l: 50.0, o: 50.0, c: 75.0}), :buy, 0)
    ]

    result = %Result{data_points: data_points, is_position_open: false, starting_balance: 100.0}

    assert Result.compile(result, []) == %Result{
             data_points: data_points,
             is_position_open: false,
             starting_balance: 100.0,
             total_profit_and_loss: 10.0
           }
  end

  test "compile/2 calculates total loss when data points exist with buy" do
    data_points = [
      DataPoint.new(InputData.munge(%{h: 100.0, l: 50.0, o: 75.0, c: 75.0}), :close, 1),
      DataPoint.new(InputData.munge(%{h: 100.0, l: 50.0, o: 50.0, c: 85.0}), :buy, 0)
    ]

    result = %Result{data_points: data_points, is_position_open: false, starting_balance: 100.0}

    assert Result.compile(result, []) == %Result{
             data_points: data_points,
             is_position_open: false,
             starting_balance: 100.0,
             total_profit_and_loss: -10.0
           }
  end

  test "compile/2 calculates total profit when data points exist with sell" do
    data_points = [
      DataPoint.new(InputData.munge(%{h: 100.0, l: 50.0, o: 75.0, c: 75.0}), :close, 1),
      DataPoint.new(InputData.munge(%{h: 100.0, l: 50.0, o: 50.0, c: 85.0}), :sell, 0)
    ]

    result = %Result{data_points: data_points, is_position_open: false, starting_balance: 100.0}

    assert Result.compile(result, []) == %Result{
             data_points: data_points,
             is_position_open: false,
             starting_balance: 100.0,
             total_profit_and_loss: 10.0
           }
  end

  test "compile/2 calculates total loss when data points exist with sell" do
    data_points = [
      DataPoint.new(InputData.munge(%{h: 100.0, l: 50.0, o: 75.0, c: 85.0}), :close, 1),
      DataPoint.new(InputData.munge(%{h: 100.0, l: 50.0, o: 50.0, c: 75.0}), :sell, 0)
    ]

    result = %Result{data_points: data_points, is_position_open: false, starting_balance: 100.0}

    assert Result.compile(result, []) == %Result{
             data_points: data_points,
             is_position_open: false,
             starting_balance: 100.0,
             total_profit_and_loss: -10.0
           }
  end
end
