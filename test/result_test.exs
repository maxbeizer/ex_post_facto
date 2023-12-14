defmodule ExPostFactoResultTest do
  use ExUnit.Case, async: true
  doctest ExPostFacto.Result

  alias ExPostFacto.{
    DataPoint,
    InputData,
    Result
  }

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
