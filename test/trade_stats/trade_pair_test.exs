defmodule TradeStats.TradePairTest do
  use ExUnit.Case, async: true
  alias ExPostFacto.DataPoint
  alias ExPostFacto.TradeStats.TradePair

  test "new/3" do
    exit_point = %DataPoint{
      datum: %{
        open: 2.0
      },
      index: 1,
      action: :close_buy
    }

    enter_point = %DataPoint{
      datum: %{
        open: 1.0
      },
      index: 0,
      action: :buy
    }

    previous_balance = 0.0

    trade_pair = TradePair.new(exit_point, enter_point, previous_balance)

    assert exit_point == trade_pair.exit_point
    assert enter_point == trade_pair.enter_point
    assert 1.0 == trade_pair.balance
    assert 0.0 = trade_pair.previous_balance
  end

  test "result/1 returns win for successful buy" do
    exit_point = %DataPoint{
      datum: %{
        open: 2.0
      },
      index: 1,
      action: :close_buy
    }

    enter_point = %DataPoint{
      datum: %{
        open: 1.0
      },
      index: 0,
      action: :buy
    }

    previous_balance = 0.0

    trade_pair = TradePair.new(exit_point, enter_point, previous_balance)

    assert :win == TradePair.result(trade_pair)
  end

  test "result/1 returns win for successful sell" do
    exit_point = %DataPoint{
      datum: %{
        open: 1.0
      },
      index: 1,
      action: :close_sell
    }

    enter_point = %DataPoint{
      datum: %{
        open: 2.0
      },
      index: 0,
      action: :sell
    }

    previous_balance = 0.0

    trade_pair = TradePair.new(exit_point, enter_point, previous_balance)

    assert :win == TradePair.result(trade_pair)
  end

  test "result/1 returns loss for unsuccessful win" do
    exit_point = %DataPoint{
      datum: %{
        open: 1.0
      },
      index: 1,
      action: :close_buy
    }

    enter_point = %DataPoint{
      datum: %{
        open: 2.0
      },
      index: 0,
      action: :buy
    }

    previous_balance = 0.0

    trade_pair = TradePair.new(exit_point, enter_point, previous_balance)

    assert :loss == TradePair.result(trade_pair)
  end

  test "result/1 returns loss for unsuccessful sell" do
    exit_point = %DataPoint{
      datum: %{
        open: 2.0
      },
      index: 1,
      action: :close_sell
    }

    enter_point = %DataPoint{
      datum: %{
        open: 1.0
      },
      index: 0,
      action: :sell
    }

    previous_balance = 0.0

    trade_pair = TradePair.new(exit_point, enter_point, previous_balance)

    assert :loss == TradePair.result(trade_pair)
  end

  test "result/1 returns break_even for break even buy" do
    exit_point = %DataPoint{
      datum: %{
        open: 1.0
      },
      index: 1,
      action: :close_buy
    }

    enter_point = %DataPoint{
      datum: %{
        open: 1.0
      },
      index: 0,
      action: :buy
    }

    previous_balance = 0.0

    trade_pair = TradePair.new(exit_point, enter_point, previous_balance)

    assert :break_even == TradePair.result(trade_pair)
  end

  test "result/1 returns break_even for break even sell" do
    exit_point = %DataPoint{
      datum: %{
        open: 1.0
      },
      index: 1,
      action: :close_sell
    }

    enter_point = %DataPoint{
      datum: %{
        open: 1.0
      },
      index: 0,
      action: :sell
    }

    previous_balance = 0.0

    trade_pair = TradePair.new(exit_point, enter_point, previous_balance)

    assert :break_even == TradePair.result(trade_pair)
  end

  test "result_percentage/1 returns 0.0 for previous_balance of 0.0" do
    exit_point = %DataPoint{
      datum: %{
        open: 1.0
      },
      index: 1,
      action: :close_sell
    }

    enter_point = %DataPoint{
      datum: %{
        open: 1.0
      },
      index: 0,
      action: :sell
    }

    previous_balance = 0.0

    trade_pair = TradePair.new(exit_point, enter_point, previous_balance)

    assert 0.0 == TradePair.result_percentage(trade_pair)
  end

  test "result_percentage/1 returns percentage for successful buy" do
    exit_point = %DataPoint{
      datum: %{
        open: 2.0
      },
      index: 1,
      action: :close_buy
    }

    enter_point = %DataPoint{
      datum: %{
        open: 1.0
      },
      index: 0,
      action: :buy
    }

    previous_balance = 2.0

    trade_pair = TradePair.new(exit_point, enter_point, previous_balance)

    # 100 * (2.0 - 1.0) / 2.0
    assert 50.0 == TradePair.result_percentage(trade_pair)
  end

  test "result_percentage/1 returns percentage for successful sell" do
    exit_point = %DataPoint{
      datum: %{
        open: 1.0
      },
      index: 1,
      action: :close_sell
    }

    enter_point = %DataPoint{
      datum: %{
        open: 2.0
      },
      index: 0,
      action: :sell
    }

    previous_balance = 2.0

    trade_pair = TradePair.new(exit_point, enter_point, previous_balance)

    # 100 * (2.0 - 1.0) / 2.0
    assert 50.0 == TradePair.result_percentage(trade_pair)
  end

  test "result_percentage/1 returns percentage for unsuccessful buy" do
    exit_point = %DataPoint{
      datum: %{
        open: 1.0
      },
      index: 1,
      action: :close_buy
    }

    enter_point = %DataPoint{
      datum: %{
        open: 2.0
      },
      index: 0,
      action: :buy
    }

    previous_balance = 2.0

    trade_pair = TradePair.new(exit_point, enter_point, previous_balance)

    # 100 * (1.0 - 2.0) / 2.0
    assert -50.0 == TradePair.result_percentage(trade_pair)
  end

  test "result_percentage/1 returns percentage for unsuccessful sell" do
    exit_point = %DataPoint{
      datum: %{
        open: 2.0
      },
      index: 1,
      action: :close_sell
    }

    enter_point = %DataPoint{
      datum: %{
        open: 1.0
      },
      index: 0,
      action: :sell
    }

    previous_balance = 2.0

    trade_pair = TradePair.new(exit_point, enter_point, previous_balance)

    # 100 * (1.0 - 2.0) / 2.0
    assert -50.0 == TradePair.result_percentage(trade_pair)
  end
end
