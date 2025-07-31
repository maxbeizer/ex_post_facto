defmodule ExPostFacto.PositionTest do
  use ExUnit.Case, async: true

  alias ExPostFacto.Position

  describe "new/6" do
    test "creates a new long position" do
      position = Position.new("AAPL", :long, 100.0, 150.0, "2023-01-01", 0)

      assert position.symbol == "AAPL"
      assert position.side == :long
      assert position.size == 100.0
      assert position.entry_price == 150.0
      assert position.entry_time == "2023-01-01"
      assert position.entry_index == 0
      assert position.current_price == 150.0
      assert position.unrealized_pl == 0.0
      assert position.unrealized_pl_pct == 0.0
      assert position.realized_pl == 0.0
      assert is_binary(position.id)
    end

    test "creates a new short position" do
      position = Position.new("TSLA", :short, 50.0, 200.0)

      assert position.symbol == "TSLA"
      assert position.side == :short
      assert position.size == 50.0
      assert position.entry_price == 200.0
      assert position.current_price == 200.0
    end
  end

  describe "update_market_data/3" do
    test "updates long position with profitable price move" do
      position = Position.new("AAPL", :long, 100.0, 150.0)
      updated_position = Position.update_market_data(position, 160.0, "2023-01-02")

      assert updated_position.current_price == 160.0
      assert updated_position.current_time == "2023-01-02"
      # (160 - 150) * 100
      assert updated_position.unrealized_pl == 1000.0
      # 1000 / (150 * 100) * 100
      assert_in_delta updated_position.unrealized_pl_pct, 6.67, 0.01
    end

    test "updates long position with loss" do
      position = Position.new("AAPL", :long, 100.0, 150.0)
      updated_position = Position.update_market_data(position, 140.0)

      assert updated_position.current_price == 140.0
      # (140 - 150) * 100
      assert updated_position.unrealized_pl == -1000.0
      assert_in_delta updated_position.unrealized_pl_pct, -6.67, 0.01
    end

    test "updates short position with profitable price move" do
      position = Position.new("TSLA", :short, 50.0, 200.0)
      updated_position = Position.update_market_data(position, 180.0)

      assert updated_position.current_price == 180.0
      # (200 - 180) * 50
      assert updated_position.unrealized_pl == 1000.0
      # 1000 / (200 * 50) * 100
      assert updated_position.unrealized_pl_pct == 10.0
    end

    test "updates short position with loss" do
      position = Position.new("TSLA", :short, 50.0, 200.0)
      updated_position = Position.update_market_data(position, 220.0)

      assert updated_position.current_price == 220.0
      # (200 - 220) * 50
      assert updated_position.unrealized_pl == -1000.0
      assert updated_position.unrealized_pl_pct == -10.0
    end
  end

  describe "partial_close/4" do
    test "partially closes long position with profit" do
      position = Position.new("AAPL", :long, 100.0, 150.0)

      {updated_position, closed_size, realized_pl} =
        Position.partial_close(position, 30.0, 160.0, "2023-01-02")

      assert closed_size == 30.0
      # (160 - 150) * 30
      assert realized_pl == 300.0
      assert updated_position.size == 70.0
      assert updated_position.realized_pl == 300.0
      assert length(updated_position.partial_closes) == 1

      [close_record] = updated_position.partial_closes
      assert close_record.size == 30.0
      assert close_record.price == 160.0
      assert close_record.time == "2023-01-02"
    end

    test "partially closes short position with profit" do
      position = Position.new("TSLA", :short, 100.0, 200.0)
      {updated_position, closed_size, realized_pl} = Position.partial_close(position, 40.0, 180.0)

      assert closed_size == 40.0
      # (200 - 180) * 40
      assert realized_pl == 800.0
      assert updated_position.size == 60.0
      assert updated_position.realized_pl == 800.0
    end

    test "cannot close more than position size" do
      position = Position.new("AAPL", :long, 100.0, 150.0)

      {updated_position, closed_size, _realized_pl} =
        Position.partial_close(position, 150.0, 160.0)

      # Limited to position size
      assert closed_size == 100.0
      assert updated_position.size == 0.0
    end

    test "updates realized P&L percentage correctly" do
      position = Position.new("AAPL", :long, 100.0, 150.0)

      {updated_position, _closed_size, _realized_pl} =
        Position.partial_close(position, 50.0, 165.0)

      # 750 realized PL / (150 entry * 50 closed size) * 100 = 10%
      assert updated_position.realized_pl_pct == 10.0
    end
  end

  describe "close/3" do
    test "fully closes long position" do
      position = Position.new("AAPL", :long, 100.0, 150.0)
      {closed_position, realized_pl} = Position.close(position, 160.0, "2023-01-02")

      assert realized_pl == 1000.0
      assert closed_position.size == 0.0
      assert closed_position.realized_pl == 1000.0
      assert Position.is_closed?(closed_position)
    end

    test "fully closes short position" do
      position = Position.new("TSLA", :short, 50.0, 200.0)
      {closed_position, realized_pl} = Position.close(position, 180.0)

      assert realized_pl == 1000.0
      assert closed_position.size == 0.0
      assert closed_position.realized_pl == 1000.0
      assert Position.is_closed?(closed_position)
    end
  end

  describe "predicates" do
    test "is_long?/1" do
      long_position = Position.new("AAPL", :long, 100.0, 150.0)
      short_position = Position.new("TSLA", :short, 50.0, 200.0)

      assert Position.is_long?(long_position)
      refute Position.is_long?(short_position)
    end

    test "is_short?/1" do
      long_position = Position.new("AAPL", :long, 100.0, 150.0)
      short_position = Position.new("TSLA", :short, 50.0, 200.0)

      refute Position.is_short?(long_position)
      assert Position.is_short?(short_position)
    end

    test "is_closed?/1" do
      open_position = Position.new("AAPL", :long, 100.0, 150.0)
      {closed_position, _} = Position.close(open_position, 160.0)

      refute Position.is_closed?(open_position)
      assert Position.is_closed?(closed_position)
    end
  end

  describe "total_pl/1 and total_pl_pct/1" do
    test "calculates total P&L correctly" do
      position = Position.new("AAPL", :long, 100.0, 150.0)

      # Partial close for some realized P&L
      {position, _, _} = Position.partial_close(position, 30.0, 160.0)

      # Update market data for unrealized P&L on remaining position
      position = Position.update_market_data(position, 165.0)

      # Realized: (160 - 150) * 30 = 300
      # Unrealized: (165 - 150) * 70 = 1050
      # Total: 300 + 1050 = 1350
      assert Position.total_pl(position) == 1350.0
    end

    test "calculates total P&L percentage correctly" do
      position = Position.new("AAPL", :long, 100.0, 150.0)

      # Partial close
      {position, _, _} = Position.partial_close(position, 30.0, 165.0)

      # Update market data
      position = Position.update_market_data(position, 160.0)

      total_pl_pct = Position.total_pl_pct(position)

      # Realized %: 10% (450 / (150 * 30) * 100)
      # Unrealized %: 6.67% (700 / (150 * 70) * 100)
      expected_total = 10.0 + 700.0 / (150.0 * 70.0) * 100.0
      assert_in_delta total_pl_pct, expected_total, 0.01
    end
  end

  describe "edge cases" do
    test "handles zero entry price for percentage calculations" do
      position = %Position{
        Position.new("TEST", :long, 100.0, 0.0)
        | entry_price: 0.0
      }

      updated_position = Position.update_market_data(position, 10.0)
      assert updated_position.unrealized_pl_pct == 0.0
    end

    test "handles zero size position" do
      position = Position.new("AAPL", :long, 0.0, 150.0)
      updated_position = Position.update_market_data(position, 160.0)

      assert updated_position.unrealized_pl == 0.0
      assert updated_position.unrealized_pl_pct == 0.0
    end
  end
end
