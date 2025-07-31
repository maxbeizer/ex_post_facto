defmodule ExPostFacto.StrategyTest do
  use ExUnit.Case
  import CandleDataHelper

  alias ExPostFacto.ExampleStrategies.{SimpleBuyHold, SmaStrategy}
  alias ExPostFacto.{Output, Result}

  describe "Strategy behaviour support" do
    test "backtest/3 works with SimpleBuyHold strategy" do
      data = [
        build_candle(open: 10.0, close: 10.5),
        build_candle(open: 10.5, close: 11.0),
        build_candle(open: 11.0, close: 11.5)
      ]

      assert {:ok, %Output{}} =
               ExPostFacto.backtest(data, {SimpleBuyHold, []}, starting_balance: 1000.0)
    end

    test "backtest/3 works with SmaStrategy" do
      data =
        1..30
        |> Enum.map(fn i ->
          price = 10.0 + i * 0.1
          build_candle(open: price, close: price + 0.05, high: price + 0.1, low: price - 0.05)
        end)

      assert {:ok, %Output{}} =
               ExPostFacto.backtest(data, {SmaStrategy, [fast_period: 5, slow_period: 10]},
                 starting_balance: 1000.0
               )
    end

    test "backtest/3 returns error for invalid strategy module" do
      data = [build_candle(open: 10.0, close: 10.5)]

      assert {:error, message} = ExPostFacto.backtest(data, {NonExistentModule, []})
      assert String.contains?(message, "strategy initialization failed")
    end

    test "backtest/3 maintains backward compatibility with MFA tuples" do
      data = [build_candle(open: 10.0, close: 10.5)]

      assert {:ok, %Output{}} =
               ExPostFacto.backtest(data, {ExPostFacto.ExampleStrategies.Noop, :noop, []})
    end

    test "SimpleBuyHold strategy produces expected data points" do
      data = [
        build_candle(open: 10.0, close: 10.5),
        build_candle(open: 10.5, close: 11.0)
      ]

      {:ok, %{result: result}} = ExPostFacto.backtest(data, {SimpleBuyHold, []})

      # Should have one buy action
      assert length(result.data_points) == 1
      assert hd(result.data_points).action == :buy
    end

    test "SmaStrategy validates periods correctly" do
      data = [build_candle(open: 10.0, close: 10.5)]

      # Should fail when fast >= slow
      assert {:error, message} =
               ExPostFacto.backtest(data, {SmaStrategy, [fast_period: 20, slow_period: 10]})

      assert String.contains?(message, "fast_period must be less than slow_period")
    end
  end
end
