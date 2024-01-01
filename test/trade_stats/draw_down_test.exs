defmodule TradeStats.DrawDownTest do
  use ExUnit.Case, async: true

  alias ExPostFacto.{
    DataPoint,
    Result
  }

  alias ExPostFacto.TradeStats.{
    DrawDown,
    TradePair
  }

  test "call!/1 returns zero if there are no trade pairs" do
    result = %Result{trade_pairs: []}

    assert 0.0 == DrawDown.call!(result).max_percentage
  end

  test "call!/1 returns zero if there is no draw down" do
    result = %Result{
      trade_pairs: [
        build_trade_pair_with_balance(100.0),
        build_trade_pair_with_balance(100.0)
      ]
    }

    assert 0.0 == DrawDown.call!(result).max_percentage
  end

  test "call!/1 returns drawdown percentage if there is draw down" do
    result = %Result{
      starting_balance: 100.0,
      trade_pairs: [
        build_trade_pair_with_balance(100.0),
        build_trade_pair_with_balance(50.0)
      ]
    }

    assert 50.0 == DrawDown.call!(result).max_percentage
  end

  test "call!/1 handles when there are multiple drawdown points up and down" do
    result = %Result{
      starting_balance: 100.0,
      trade_pairs: [
        build_trade_pair_with_balance(50.0),
        build_trade_pair_with_balance(100.0),
        build_trade_pair_with_balance(50.0)
      ]
    }

    assert 50.0 == DrawDown.call!(result).max_percentage
  end

  test "call!/1 handles when there are multiple drawdown points after one another" do
    result = %Result{
      starting_balance: 100.0,
      trade_pairs: [
        build_trade_pair_with_balance(100.0),
        build_trade_pair_with_balance(90.0),
        build_trade_pair_with_balance(50.0)
      ]
    }

    assert 50.0 == DrawDown.call!(result).max_percentage
  end

  test "call!/1 handles when there are multiple drawdown points up down and up" do
    result = %Result{
      starting_balance: 100.0,
      trade_pairs: [
        build_trade_pair_with_balance(90.0),
        build_trade_pair_with_balance(100.0),
        build_trade_pair_with_balance(50.0),
        build_trade_pair_with_balance(90.0)
      ]
    }

    assert 10.0 == DrawDown.call!(result).max_percentage
  end

  test "call!/1 calculates average drawdown correctly when there are no drawdowns" do
    result = %Result{
      starting_balance: 100.0,
      trade_pairs: [
        build_trade_pair_with_balance(100.0),
        build_trade_pair_with_balance(110.0),
        build_trade_pair_with_balance(120.0)
      ]
    }

    assert 0.0 == DrawDown.call!(result).average_percentage
  end

  test "call!/1 calculates average drawdown correctly when there is one drawdown" do
    result = %Result{
      starting_balance: 100.0,
      trade_pairs: [
        build_trade_pair_with_balance(100.0),
        build_trade_pair_with_balance(90.0)
      ]
    }

    assert 10.0 == DrawDown.call!(result).average_percentage
  end

  test "call!/1 calculates average drawdown correctly when there are multiple drawdowns" do
    result = %Result{
      starting_balance: 100.0,
      trade_pairs: [
        build_trade_pair_with_balance(100.0),
        build_trade_pair_with_balance(90.0),
        build_trade_pair_with_balance(100.0),
        build_trade_pair_with_balance(80.0)
      ]
    }

    assert 15.0 == DrawDown.call!(result).average_percentage
  end

  test "call!/1 calculates max drawdown duration when no trade pairs" do
    result = %Result{
      starting_balance: 100.0,
      trade_pairs: []
    }

    assert 0 == DrawDown.call!(result).max_duration
  end

  test "call!/1 calculates max drawdown duration when no draw down" do
    result = %Result{
      starting_balance: 100.0,
      trade_pairs: [
        build_trade_pair_with_balance(100.0)
      ]
    }

    assert 0 == DrawDown.call!(result).max_duration
  end

  test "call!/1 calculates max drawdown duration with two data points" do
    result = %Result{
      starting_balance: 100.0,
      trade_pairs: [
        build_trade_pair_with_balance(100.0, enter_date: "2018-01-01", duration_days: 1),
        build_trade_pair_with_balance(10.0, enter_date: "2018-01-02", duration_days: 10)
      ]
    }

    assert 10 == DrawDown.call!(result).max_duration
  end

  defp build_trade_pair_with_balance(balance, options \\ []) do
    duration_days = Keyword.get(options, :duration_days, 1)
    enter_date = Keyword.get(options, :enter_date, Date.to_string(Date.new!(2018, 1, 1)))
    exit_date = enter_date |> Date.from_iso8601!() |> Date.add(duration_days) |> Date.to_string()

    exit_point = %DataPoint{
      action: :close_buy,
      index: 1,
      datum: %{open: 100.0, timestamp: exit_date}
    }

    enter_point = %DataPoint{
      action: :buy,
      index: 0,
      datum: %{open: 100.0, timestamp: enter_date}
    }

    TradePair.new(exit_point, enter_point, balance)
  end
end
