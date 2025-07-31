defmodule ExPostFacto.PortfolioTest do
  use ExUnit.Case, async: true

  alias ExPostFacto.{Portfolio, Position, Order}

  describe "new/1" do
    test "creates an empty portfolio" do
      portfolio = Portfolio.new(10000.0)

      assert portfolio.equity == 10000.0
      assert portfolio.available_cash == 10000.0
      assert map_size(portfolio.positions) == 0
      assert map_size(portfolio.orders) == 0
      assert length(portfolio.order_history) == 0
      assert length(portfolio.position_history) == 0
    end

    test "creates portfolio with default equity" do
      portfolio = Portfolio.new()

      assert portfolio.equity == 0.0
      assert portfolio.available_cash == 0.0
    end
  end

  describe "order management" do
    test "add_order/2 adds order to portfolio" do
      portfolio = Portfolio.new(10000.0)
      order = Order.market("AAPL", :buy, 100.0)

      updated_portfolio = Portfolio.add_order(portfolio, order)

      assert map_size(updated_portfolio.orders) == 1
      assert Map.has_key?(updated_portfolio.orders, order.id)
    end

    test "remove_order/2 removes order and adds to history" do
      portfolio = Portfolio.new(10000.0)
      order = Order.market("AAPL", :buy, 100.0)

      portfolio = Portfolio.add_order(portfolio, order)
      updated_portfolio = Portfolio.remove_order(portfolio, order.id)

      assert map_size(updated_portfolio.orders) == 0
      assert length(updated_portfolio.order_history) == 1
      assert hd(updated_portfolio.order_history) == order
    end

    test "remove_order/2 handles non-existent order" do
      portfolio = Portfolio.new(10000.0)
      updated_portfolio = Portfolio.remove_order(portfolio, "non-existent")

      assert updated_portfolio == portfolio
    end
  end

  describe "position management" do
    test "add_position/2 adds position to portfolio" do
      portfolio = Portfolio.new(10000.0)
      position = Position.new("AAPL", :long, 100.0, 150.0)

      updated_portfolio = Portfolio.add_position(portfolio, position)

      assert map_size(updated_portfolio.positions) == 1
      assert Map.has_key?(updated_portfolio.positions, position.id)
    end

    test "update_position/3 updates existing position" do
      portfolio = Portfolio.new(10000.0)
      position = Position.new("AAPL", :long, 100.0, 150.0)
      portfolio = Portfolio.add_position(portfolio, position)

      updated_position = Position.update_market_data(position, 160.0)
      updated_portfolio = Portfolio.update_position(portfolio, position.id, updated_position)

      stored_position = Map.get(updated_portfolio.positions, position.id)
      assert stored_position.current_price == 160.0
      assert stored_position.unrealized_pl == 1000.0
    end

    test "update_position/3 handles non-existent position" do
      portfolio = Portfolio.new(10000.0)
      position = Position.new("AAPL", :long, 100.0, 150.0)
      updated_portfolio = Portfolio.update_position(portfolio, "non-existent", position)

      assert updated_portfolio == portfolio
    end

    test "remove_position/2 removes position and adds to history" do
      portfolio = Portfolio.new(10000.0)
      position = Position.new("AAPL", :long, 100.0, 150.0)

      portfolio = Portfolio.add_position(portfolio, position)
      updated_portfolio = Portfolio.remove_position(portfolio, position.id)

      assert map_size(updated_portfolio.positions) == 0
      assert length(updated_portfolio.position_history) == 1
      assert hd(updated_portfolio.position_history) == position
    end
  end

  describe "get_positions/1 and variants" do
    setup do
      portfolio = Portfolio.new(10000.0)
      aapl_long = Position.new("AAPL", :long, 100.0, 150.0)
      aapl_short = Position.new("AAPL", :short, 50.0, 160.0)
      tsla_long = Position.new("TSLA", :long, 25.0, 800.0)

      portfolio =
        portfolio
        |> Portfolio.add_position(aapl_long)
        |> Portfolio.add_position(aapl_short)
        |> Portfolio.add_position(tsla_long)

      {:ok,
       portfolio: portfolio, aapl_long: aapl_long, aapl_short: aapl_short, tsla_long: tsla_long}
    end

    test "get_positions/1 returns all positions", %{portfolio: portfolio} do
      positions = Portfolio.get_positions(portfolio)
      assert length(positions) == 3
    end

    test "get_positions_for_symbol/2 returns positions for specific symbol", %{
      portfolio: portfolio
    } do
      aapl_positions = Portfolio.get_positions_for_symbol(portfolio, "AAPL")
      tsla_positions = Portfolio.get_positions_for_symbol(portfolio, "TSLA")

      assert length(aapl_positions) == 2
      assert length(tsla_positions) == 1
      assert Enum.all?(aapl_positions, &(&1.symbol == "AAPL"))
      assert Enum.all?(tsla_positions, &(&1.symbol == "TSLA"))
    end

    test "get_long_positions/1 returns only long positions", %{portfolio: portfolio} do
      long_positions = Portfolio.get_long_positions(portfolio)
      assert length(long_positions) == 2
      assert Enum.all?(long_positions, &Position.is_long?/1)
    end

    test "get_short_positions/1 returns only short positions", %{portfolio: portfolio} do
      short_positions = Portfolio.get_short_positions(portfolio)
      assert length(short_positions) == 1
      assert Enum.all?(short_positions, &Position.is_short?/1)
    end
  end

  describe "get_pending_orders/1 and variants" do
    setup do
      portfolio = Portfolio.new(10000.0)
      aapl_buy = Order.market("AAPL", :buy, 100.0)
      aapl_sell = Order.limit("AAPL", :sell, 50.0, 160.0)
      tsla_buy = Order.stop("TSLA", :buy, 25.0, 820.0)
      filled_order = Order.fill(Order.market("MSFT", :buy, 10.0), 300.0)

      portfolio =
        portfolio
        |> Portfolio.add_order(aapl_buy)
        |> Portfolio.add_order(aapl_sell)
        |> Portfolio.add_order(tsla_buy)
        |> Portfolio.add_order(filled_order)

      {:ok, portfolio: portfolio}
    end

    test "get_pending_orders/1 returns only pending orders", %{portfolio: portfolio} do
      pending_orders = Portfolio.get_pending_orders(portfolio)
      assert length(pending_orders) == 3
      assert Enum.all?(pending_orders, &Order.is_pending?/1)
    end

    test "get_pending_orders_for_symbol/2 returns pending orders for specific symbol", %{
      portfolio: portfolio
    } do
      aapl_orders = Portfolio.get_pending_orders_for_symbol(portfolio, "AAPL")
      tsla_orders = Portfolio.get_pending_orders_for_symbol(portfolio, "TSLA")
      msft_orders = Portfolio.get_pending_orders_for_symbol(portfolio, "MSFT")

      assert length(aapl_orders) == 2
      assert length(tsla_orders) == 1
      # MSFT order is filled, not pending
      assert length(msft_orders) == 0
    end
  end

  describe "get_net_position_size/2" do
    test "calculates net position size correctly" do
      portfolio = Portfolio.new(10000.0)
      long_position = Position.new("AAPL", :long, 100.0, 150.0)
      short_position = Position.new("AAPL", :short, 30.0, 160.0)

      portfolio =
        portfolio
        |> Portfolio.add_position(long_position)
        |> Portfolio.add_position(short_position)

      net_size = Portfolio.get_net_position_size(portfolio, "AAPL")
      # 100 long - 30 short
      assert net_size == 70.0
    end

    test "returns zero for symbol with no positions" do
      portfolio = Portfolio.new(10000.0)
      net_size = Portfolio.get_net_position_size(portfolio, "TSLA")
      assert net_size == 0.0
    end
  end

  describe "P&L calculations" do
    setup do
      portfolio = Portfolio.new(10000.0)

      # Create positions with some P&L
      long_position = Position.new("AAPL", :long, 100.0, 150.0)
      # +1000 unrealized
      long_position = Position.update_market_data(long_position, 160.0)

      short_position = Position.new("TSLA", :short, 50.0, 800.0)
      # +1000 unrealized
      short_position = Position.update_market_data(short_position, 780.0)

      # Position with realized P&L
      {mixed_position, _, _} =
        Position.partial_close(
          Position.new("MSFT", :long, 100.0, 300.0),
          50.0,
          320.0
        )

      # +1000 realized
      # +500 unrealized on remaining 50
      mixed_position = Position.update_market_data(mixed_position, 310.0)

      portfolio =
        portfolio
        |> Portfolio.add_position(long_position)
        |> Portfolio.add_position(short_position)
        |> Portfolio.add_position(mixed_position)

      # Add some closed position to history
      # +1000 realized
      {closed_position, _} = Position.close(Position.new("NVDA", :long, 20.0, 500.0), 550.0)
      portfolio = %{portfolio | position_history: [closed_position]}

      {:ok, portfolio: portfolio}
    end

    test "total_unrealized_pl/1 calculates correctly", %{portfolio: portfolio} do
      unrealized_pl = Portfolio.total_unrealized_pl(portfolio)
      # 1000 + 1000 + 500
      assert unrealized_pl == 2500.0
    end

    test "total_realized_pl/1 includes current and historical positions", %{portfolio: portfolio} do
      realized_pl = Portfolio.total_realized_pl(portfolio)
      # 1000 (current) + 1000 (historical)
      assert realized_pl == 2000.0
    end

    test "total_pl/1 combines realized and unrealized", %{portfolio: portfolio} do
      total_pl = Portfolio.total_pl(portfolio)
      # 2500 unrealized + 2000 realized
      assert total_pl == 4500.0
    end
  end

  describe "update_equity/2" do
    test "updates equity based on total P&L" do
      portfolio = Portfolio.new(10000.0)
      position = Position.new("AAPL", :long, 100.0, 150.0)
      # +1000 P&L
      position = Position.update_market_data(position, 160.0)

      portfolio = Portfolio.add_position(portfolio, position)
      updated_portfolio = Portfolio.update_equity(portfolio, 10000.0)

      # 10000 + 1000
      assert updated_portfolio.equity == 11000.0
    end
  end

  describe "update_market_data/4" do
    test "updates all positions for given symbol" do
      portfolio = Portfolio.new(10000.0)
      position1 = Position.new("AAPL", :long, 100.0, 150.0)
      position2 = Position.new("AAPL", :short, 50.0, 160.0)
      position3 = Position.new("TSLA", :long, 25.0, 800.0)

      portfolio =
        portfolio
        |> Portfolio.add_position(position1)
        |> Portfolio.add_position(position2)
        |> Portfolio.add_position(position3)

      updated_portfolio = Portfolio.update_market_data(portfolio, "AAPL", 170.0, "2023-01-02")

      aapl_positions = Portfolio.get_positions_for_symbol(updated_portfolio, "AAPL")
      tsla_positions = Portfolio.get_positions_for_symbol(updated_portfolio, "TSLA")

      # AAPL positions should be updated
      assert Enum.all?(aapl_positions, &(&1.current_price == 170.0))
      assert Enum.all?(aapl_positions, &(&1.current_time == "2023-01-02"))

      # TSLA position should remain unchanged
      assert Enum.all?(tsla_positions, &(&1.current_price == 800.0))
    end
  end

  describe "predicates" do
    test "has_positions?/1" do
      empty_portfolio = Portfolio.new(10000.0)
      position = Position.new("AAPL", :long, 100.0, 150.0)
      portfolio_with_position = Portfolio.add_position(empty_portfolio, position)

      refute Portfolio.has_positions?(empty_portfolio)
      assert Portfolio.has_positions?(portfolio_with_position)
    end

    test "has_pending_orders?/1" do
      empty_portfolio = Portfolio.new(10000.0)
      pending_order = Order.market("AAPL", :buy, 100.0)
      filled_order = Order.fill(Order.market("TSLA", :buy, 50.0), 800.0)

      portfolio_with_pending = Portfolio.add_order(empty_portfolio, pending_order)
      portfolio_with_filled = Portfolio.add_order(empty_portfolio, filled_order)

      refute Portfolio.has_pending_orders?(empty_portfolio)
      assert Portfolio.has_pending_orders?(portfolio_with_pending)
      refute Portfolio.has_pending_orders?(portfolio_with_filled)
    end
  end

  describe "get_summary/1" do
    test "returns comprehensive portfolio summary" do
      portfolio = Portfolio.new(10000.0)

      # Add positions and orders
      position = Position.new("AAPL", :long, 100.0, 150.0)
      # +1000 unrealized
      position = Position.update_market_data(position, 160.0)
      # +750 realized
      {position, _, _} = Position.partial_close(position, 50.0, 165.0)

      pending_order = Order.market("TSLA", :buy, 25.0)
      filled_order = Order.fill(Order.market("MSFT", :buy, 10.0), 300.0)

      portfolio =
        portfolio
        |> Portfolio.add_position(position)
        |> Portfolio.add_order(pending_order)
        |> Portfolio.add_order(filled_order)
        |> Portfolio.update_equity(10000.0)

      summary = Portfolio.get_summary(portfolio)

      assert summary.total_positions == 1
      assert summary.total_pending_orders == 1
      # (160-150) * 50 remaining shares
      assert summary.total_unrealized_pl == 500.0
      assert summary.total_realized_pl == 750.0
      assert summary.total_pl == 1250.0
      # 10000 + 1250
      assert summary.equity == 11250.0
      assert summary.available_cash == 10000.0
    end
  end
end
