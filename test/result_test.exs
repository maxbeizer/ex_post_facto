defmodule ExPostFactoResultTest do
  use ExUnit.Case, async: true
  doctest ExPostFacto.Result
  import CandleDataHelper

  alias ExPostFacto.{
    DataPoint,
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
      DataPoint.new(build_candle(open: 0.0), :buy, 2)
    ]

    result =
      %Result{data_points: data_points, is_position_open: true}
      |> Result.add_data_point(3, %{}, :close_buy)

    assert 1 == result.trades_count
  end

  test "counts the number of closed trades (multiple) when all closed" do
    data_points = [
      DataPoint.new(build_candle(open: 0.0), :buy, 2),
      DataPoint.new(build_candle(open: 0.0), :close_buy, 1),
      DataPoint.new(build_candle(open: 0.0), :buy, 0)
    ]

    # start with one trade count from the data above
    result =
      %Result{data_points: data_points, is_position_open: true, trades_count: 1}
      |> Result.add_data_point(3, %{}, :close_buy)

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
    result =
      %Result{data_points: [], is_position_open: false, starting_balance: 0.0}
      |> Result.compile()

    assert %Result{
             data_points: [],
             is_position_open: false,
             starting_balance: 0.0,
             total_profit_and_loss: 0.0
           } == result
  end

  test "compile/2 calculates total profit when data points exist with buy" do
    data_points = [
      DataPoint.new(build_candle(open: 10.0), :close_buy, 1),
      DataPoint.new(build_candle(open: 0.0), :buy, 0)
    ]

    result =
      %Result{data_points: data_points, is_position_open: false, starting_balance: 100.0}
      |> Result.compile()

    assert 10 == result.total_profit_and_loss
  end

  test "compile/2 calculates total loss when data points exist with buy" do
    data_points = [
      DataPoint.new(build_candle(open: 0.0), :close_buy, 1),
      DataPoint.new(build_candle(open: 10.0), :buy, 0)
    ]

    result =
      %Result{data_points: data_points, is_position_open: false, starting_balance: 100.0}
      |> Result.compile()

    assert -10 == result.total_profit_and_loss
  end

  test "compile/2 calculates total profit when data points exist with sell" do
    data_points = [
      DataPoint.new(build_candle(open: 0.0), :close_sell, 1),
      DataPoint.new(build_candle(open: 10.0), :sell, 0)
    ]

    result =
      %Result{data_points: data_points, is_position_open: false, starting_balance: 100.0}
      |> Result.compile()

    assert 10.0 == result.total_profit_and_loss
  end

  test "compile/2 calculates total loss when data points exist with sell" do
    data_points = [
      DataPoint.new(build_candle(open: 10.0), :close_sell, 1),
      DataPoint.new(build_candle(open: 0.0), :sell, 0)
    ]

    result =
      %Result{data_points: data_points, is_position_open: false, starting_balance: 100.0}
      |> Result.compile()

    assert -10.0 == result.total_profit_and_loss
  end

  test "compile/2 calculates the win rate as 0.0 when no data points" do
    data_points = []

    result =
      %Result{data_points: data_points}
      |> Result.compile()

    assert 0.0 == result.win_rate
  end

  test "compile/2 calculates the win rate as 0.0 when no wins" do
    data_points = [
      DataPoint.new(build_candle(open: 10.0), :close_sell, 1),
      DataPoint.new(build_candle(open: 0.0), :sell, 0)
    ]

    result =
      %Result{data_points: data_points}
      |> Result.compile()

    assert 0.0 == result.win_rate
  end

  test "compile/2 calculates the win rate as 100.0 when all wins" do
    result =
      %Result{data_points: []}
      |> Result.add_data_point(0, build_candle(open: 0.0), :buy)
      |> Result.add_data_point(1, build_candle(open: 10.0), :close_buy)
      |> Result.compile()

    assert 100.0 == result.win_rate
  end

  test "compile/2 calculates the win rate as 50.0 when half wins" do
    result =
      %Result{data_points: []}
      |> Result.add_data_point(0, build_candle(open: 10.0), :buy)
      |> Result.add_data_point(1, build_candle(open: 0.0), :close_buy)
      |> Result.add_data_point(2, build_candle(open: 0.0), :buy)
      |> Result.add_data_point(3, build_candle(open: 10.0), :close_buy)
      |> Result.compile()

    assert 50.0 == result.win_rate
  end

  test "compile/2 calculates best win by percentage as zero when there are no data points" do
    result =
      %Result{data_points: []}
      |> Result.compile()

    assert 0.0 == result.best_trade_by_percentage
  end

  test "compile/2 calculates best win by percentage as negative when there are no winners" do
    result =
      %Result{data_points: [], starting_balance: 100.0}
      |> Result.add_data_point(2, build_candle(open: 10.0), :buy)
      |> Result.add_data_point(3, build_candle(open: 0.0), :close_buy)
      |> Result.compile()

    assert -10.0 == result.best_trade_by_percentage
  end

  test "compile/2 calculates best win by percentage when there are winners" do
    result =
      %Result{data_points: [], starting_balance: 100.0}
      |> Result.add_data_point(2, build_candle(open: 0.0), :buy)
      |> Result.add_data_point(3, build_candle(open: 10.0), :close_buy)
      |> Result.compile()

    assert 10.0 == result.best_trade_by_percentage
  end

  test "compile/2 calculates worst win by percentage as zero when there are no data points" do
    result =
      %Result{data_points: []}
      |> Result.compile()

    assert 0.0 == result.worst_trade_by_percentage
  end

  test "compile/2 calculates worst win by percentage as negative when there are no winners" do
    result =
      %Result{data_points: [], starting_balance: 100.0}
      |> Result.add_data_point(2, build_candle(open: 10.0), :buy)
      |> Result.add_data_point(3, build_candle(open: 0.0), :close_buy)
      |> Result.compile()

    assert -10.0 == result.worst_trade_by_percentage
  end

  test "compile/2 calculates worst win by percentage when there are winners" do
    result =
      %Result{data_points: [], starting_balance: 100.0}
      |> Result.add_data_point(2, build_candle(open: 0.0), :buy)
      |> Result.add_data_point(3, build_candle(open: 10.0), :close_buy)
      |> Result.compile()

    assert 10.0 == result.worst_trade_by_percentage
  end
end
