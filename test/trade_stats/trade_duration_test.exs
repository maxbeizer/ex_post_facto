defmodule TradeStats.TradeDurationTest do
  use ExUnit.Case, async: true

  alias ExPostFacto.Result
  alias ExPostFacto.TradeStats.TradeDuration

  test "max!/1 when on only one data point, returns the duration" do
    result =
      Result.new()
      |> Result.add_data_point(0, %{open: 100.0, timestamp: "2023-12-23"}, :buy)
      |> Result.add_data_point(1, %{open: 200.0, timestamp: "2023-12-24"}, :close_buy)
      |> Result.compile()

    duration = TradeDuration.max!(result)
    assert 1 == duration
  end

  test "max!/1 when multiple data points, returns the duration" do
    result =
      Result.new()
      |> Result.add_data_point(0, %{open: 100.0, timestamp: "2023-12-20"}, :buy)
      |> Result.add_data_point(1, %{open: 200.0, timestamp: "2023-12-21"}, :close_buy)
      |> Result.add_data_point(2, %{open: 100.0, timestamp: "2023-12-21"}, :buy)
      |> Result.add_data_point(3, %{open: 100.0, timestamp: "2023-12-24"}, :close_buy)
      |> Result.compile()

    duration = TradeDuration.max!(result)
    # 24-21 = 3
    assert 3 == duration
  end

  test "max!/1 when no data points, returns 0.0" do
    result =
      Result.new()
      |> Result.compile()

    duration = TradeDuration.max!(result)
    assert 0.0 == duration
  end

  test "max!/1 returns intraday duration" do
    result =
      Result.new()
      |> Result.add_data_point(0, %{open: 100.0, timestamp: "2023-12-24T13:14:42.660407Z"}, :buy)
      |> Result.add_data_point(
        1,
        %{open: 101.0, timestamp: "2023-12-24T14:14:42.660407Z"},
        :close_buy
      )
      |> Result.compile()

    duration = TradeDuration.max!(result)
    assert 1 / 24 == duration
  end

  test "max!/1 returns duration on sells as well" do
    result =
      Result.new()
      |> Result.add_data_point(0, %{open: 101.0, timestamp: "2023-12-23"}, :sell)
      |> Result.add_data_point(1, %{open: 100.0, timestamp: "2023-12-24"}, :close_sell)
      |> Result.compile()

    duration = TradeDuration.max!(result)
    assert 1.0 == duration
  end

  test "average!/1 when on only one data point, returns the duration" do
    result =
      Result.new()
      |> Result.add_data_point(0, %{open: 100.0, timestamp: "2023-12-23"}, :buy)
      |> Result.add_data_point(1, %{open: 200.0, timestamp: "2023-12-24"}, :close_buy)
      |> Result.compile()

    duration = TradeDuration.average!(result)
    assert 1.0 == duration
  end

  test "average!/1 when multiple data points, returns the duration" do
    result =
      Result.new()
      |> Result.add_data_point(0, %{open: 100.0, timestamp: "2023-12-23"}, :buy)
      |> Result.add_data_point(1, %{open: 200.0, timestamp: "2023-12-24"}, :close_buy)
      |> Result.add_data_point(2, %{open: 100.0, timestamp: "2023-12-23"}, :buy)
      |> Result.add_data_point(3, %{open: 100.0, timestamp: "2023-12-24"}, :close_buy)
      |> Result.compile()

    duration = TradeDuration.average!(result)
    assert 1.0 == duration
  end

  test "average!/1 when no data points, returns 0.0" do
    result =
      Result.new()
      |> Result.compile()

    duration = TradeDuration.average!(result)
    assert 0.0 == duration
  end

  test "average!/1 returns intraday duration averages as a float of a day" do
    result =
      Result.new()
      |> Result.add_data_point(0, %{open: 100.0, timestamp: "2023-12-24T13:13:42.660407Z"}, :buy)
      |> Result.add_data_point(
        1,
        %{open: 101.0, timestamp: "2023-12-24T13:14:42.660407Z"},
        :close_buy
      )
      |> Result.compile()

    duration = TradeDuration.average!(result)
    # One minute difference
    assert 60 / 86400 == duration
  end

  test "average!/1 returns duration on sells as well" do
    result =
      Result.new()
      |> Result.add_data_point(0, %{open: 101.0, timestamp: "2023-12-23"}, :sell)
      |> Result.add_data_point(1, %{open: 100.0, timestamp: "2023-12-24"}, :close_sell)
      |> Result.compile()

    duration = TradeDuration.average!(result)
    assert 1.0 == duration
  end
end
