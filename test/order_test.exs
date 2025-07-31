defmodule ExPostFacto.OrderTest do
  use ExUnit.Case, async: true

  alias ExPostFacto.Order

  describe "market/4" do
    test "creates a market order" do
      order = Order.market("AAPL", :buy, 100.0)

      assert order.type == :market
      assert order.symbol == "AAPL"
      assert order.side == :buy
      assert order.size == 100.0
      assert order.status == :pending
      assert order.time_in_force == :day
      assert is_binary(order.id)
    end

    test "creates a market order with options" do
      order =
        Order.market("AAPL", :sell, 50.0,
          stop_loss: 145.0,
          take_profit: 155.0,
          time_in_force: :gtc
        )

      assert order.stop_loss == 145.0
      assert order.take_profit == 155.0
      assert order.time_in_force == :gtc
    end
  end

  describe "limit/5" do
    test "creates a limit order" do
      order = Order.limit("TSLA", :buy, 75.0, 200.0)

      assert order.type == :limit
      assert order.symbol == "TSLA"
      assert order.side == :buy
      assert order.size == 75.0
      assert order.limit_price == 200.0
      assert order.status == :pending
      assert order.time_in_force == :gtc
    end
  end

  describe "stop/5" do
    test "creates a stop order" do
      order = Order.stop("MSFT", :sell, 25.0, 300.0)

      assert order.type == :stop
      assert order.symbol == "MSFT"
      assert order.side == :sell
      assert order.size == 25.0
      assert order.stop_price == 300.0
      assert order.status == :pending
    end
  end

  describe "stop_limit/6" do
    test "creates a stop-limit order" do
      order = Order.stop_limit("GOOGL", :sell, 10.0, 2800.0, 2750.0)

      assert order.type == :stop_limit
      assert order.symbol == "GOOGL"
      assert order.side == :sell
      assert order.size == 10.0
      assert order.stop_price == 2800.0
      assert order.limit_price == 2750.0
      assert order.status == :pending
    end
  end

  describe "can_fill?/2" do
    test "market orders can always be filled" do
      order = Order.market("AAPL", :buy, 100.0)

      assert Order.can_fill?(order, 150.0)
      assert Order.can_fill?(order, 200.0)
      assert Order.can_fill?(order, 100.0)
    end

    test "limit buy order can be filled at or below limit price" do
      order = Order.limit("AAPL", :buy, 100.0, 150.0)

      # At limit
      assert Order.can_fill?(order, 150.0)
      # Below limit
      assert Order.can_fill?(order, 149.0)
      # Above limit
      refute Order.can_fill?(order, 151.0)
    end

    test "limit sell order can be filled at or above limit price" do
      order = Order.limit("AAPL", :sell, 100.0, 150.0)

      # At limit
      assert Order.can_fill?(order, 150.0)
      # Above limit
      assert Order.can_fill?(order, 151.0)
      # Below limit
      refute Order.can_fill?(order, 149.0)
    end

    test "stop buy order can be filled at or above stop price" do
      order = Order.stop("AAPL", :buy, 100.0, 150.0)

      # At stop
      assert Order.can_fill?(order, 150.0)
      # Above stop
      assert Order.can_fill?(order, 151.0)
      # Below stop
      refute Order.can_fill?(order, 149.0)
    end

    test "stop sell order can be filled at or below stop price" do
      order = Order.stop("AAPL", :sell, 100.0, 150.0)

      # At stop
      assert Order.can_fill?(order, 150.0)
      # Below stop
      assert Order.can_fill?(order, 149.0)
      # Above stop
      refute Order.can_fill?(order, 151.0)
    end

    test "stop-limit buy order can be filled between stop and limit" do
      order = Order.stop_limit("AAPL", :buy, 100.0, 150.0, 155.0)

      # At stop
      assert Order.can_fill?(order, 150.0)
      # Between stop and limit
      assert Order.can_fill?(order, 152.0)
      # At limit
      assert Order.can_fill?(order, 155.0)
      # Below stop
      refute Order.can_fill?(order, 149.0)
      # Above limit
      refute Order.can_fill?(order, 156.0)
    end

    test "stop-limit sell order can be filled between limit and stop" do
      order = Order.stop_limit("AAPL", :sell, 100.0, 150.0, 145.0)

      # At stop
      assert Order.can_fill?(order, 150.0)
      # Between limit and stop
      assert Order.can_fill?(order, 147.0)
      # At limit
      assert Order.can_fill?(order, 145.0)
      # Above stop
      refute Order.can_fill?(order, 151.0)
      # Below limit
      refute Order.can_fill?(order, 144.0)
    end

    test "filled orders cannot be filled again" do
      order = Order.market("AAPL", :buy, 100.0)
      filled_order = Order.fill(order, 150.0)

      refute Order.can_fill?(filled_order, 150.0)
    end

    test "cancelled orders cannot be filled" do
      order = Order.market("AAPL", :buy, 100.0)
      cancelled_order = Order.cancel(order)

      refute Order.can_fill?(cancelled_order, 150.0)
    end
  end

  describe "fill/5" do
    test "fills an order completely" do
      order = Order.market("AAPL", :buy, 100.0)
      filled_order = Order.fill(order, 150.0, "2023-01-01", 1, 5.0)

      assert filled_order.status == :filled
      assert filled_order.filled_price == 150.0
      assert filled_order.filled_size == 100.0
      assert filled_order.filled_at == "2023-01-01"
      assert filled_order.filled_index == 1
      assert filled_order.commission == 5.0
    end
  end

  describe "partial_fill/6" do
    test "partially fills an order" do
      order = Order.market("AAPL", :buy, 100.0)
      partially_filled = Order.partial_fill(order, 30.0, 150.0, "2023-01-01", 1, 2.0)

      assert partially_filled.status == :partially_filled
      assert partially_filled.filled_price == 150.0
      assert partially_filled.filled_size == 30.0
      assert partially_filled.commission == 2.0
      assert Order.remaining_size(partially_filled) == 70.0
    end

    test "completely fills order with partial_fill when full size is filled" do
      order = Order.market("AAPL", :buy, 100.0)
      filled_order = Order.partial_fill(order, 100.0, 150.0)

      assert filled_order.status == :filled
      assert filled_order.filled_size == 100.0
      assert Order.remaining_size(filled_order) == 0.0
    end

    test "accumulates partial fills" do
      order = Order.market("AAPL", :buy, 100.0)
      first_fill = Order.partial_fill(order, 30.0, 150.0, nil, nil, 1.0)
      second_fill = Order.partial_fill(first_fill, 40.0, 151.0, nil, nil, 1.5)

      assert second_fill.filled_size == 70.0
      assert second_fill.commission == 2.5
      assert second_fill.status == :partially_filled
      assert Order.remaining_size(second_fill) == 30.0
    end
  end

  describe "cancel/1" do
    test "cancels a pending order" do
      order = Order.market("AAPL", :buy, 100.0)
      cancelled_order = Order.cancel(order)

      assert cancelled_order.status == :cancelled
    end
  end

  describe "predicates" do
    test "is_pending?/1" do
      pending_order = Order.market("AAPL", :buy, 100.0)
      filled_order = Order.fill(pending_order, 150.0)
      cancelled_order = Order.cancel(pending_order)

      assert Order.is_pending?(pending_order)
      refute Order.is_pending?(filled_order)
      refute Order.is_pending?(cancelled_order)
    end

    test "is_filled?/1" do
      pending_order = Order.market("AAPL", :buy, 100.0)
      filled_order = Order.fill(pending_order, 150.0)

      refute Order.is_filled?(pending_order)
      assert Order.is_filled?(filled_order)
    end

    test "is_partially_filled?/1" do
      order = Order.market("AAPL", :buy, 100.0)
      partially_filled = Order.partial_fill(order, 30.0, 150.0)
      fully_filled = Order.fill(order, 150.0)

      refute Order.is_partially_filled?(order)
      assert Order.is_partially_filled?(partially_filled)
      refute Order.is_partially_filled?(fully_filled)
    end
  end

  describe "remaining_size/1" do
    test "returns full size for unfilled order" do
      order = Order.market("AAPL", :buy, 100.0)
      assert Order.remaining_size(order) == 100.0
    end

    test "returns remaining size for partially filled order" do
      order = Order.market("AAPL", :buy, 100.0)
      partially_filled = Order.partial_fill(order, 30.0, 150.0)
      assert Order.remaining_size(partially_filled) == 70.0
    end

    test "returns zero for fully filled order" do
      order = Order.market("AAPL", :buy, 100.0)
      filled_order = Order.fill(order, 150.0)
      assert Order.remaining_size(filled_order) == 0.0
    end
  end

  describe "edge cases" do
    test "orders have unique IDs" do
      order1 = Order.market("AAPL", :buy, 100.0)
      order2 = Order.market("AAPL", :buy, 100.0)

      assert order1.id != order2.id
    end

    test "handles zero commission" do
      order = Order.market("AAPL", :buy, 100.0)
      filled_order = Order.fill(order, 150.0)

      assert filled_order.commission == 0.0
    end
  end
end
