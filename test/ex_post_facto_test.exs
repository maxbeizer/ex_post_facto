defmodule ExPostFactoTest do
  use ExUnit.Case, async: true
  doctest ExPostFacto

  alias ExPostFacto.ExampleStrategies.Noop
  alias ExPostFacto.Output

  test "backtest/3 returns an error when data is nil" do
    assert {:error, "data cannot be nil"} = ExPostFacto.backtest(nil, {Noop, :noop, []})
  end

  test "backtest/3 returns an error when strategy is nil" do
    assert {:error, "strategy cannot be nil"} = ExPostFacto.backtest([], nil)
  end

  test "backtest/3 returns an output struct" do
    assert {:ok, %Output{}} = ExPostFacto.backtest([], {Noop, :noop, []})
  end

  test "backtest/3 returns an output struct with the data" do
    example_data = [%{high: 1.0, low: 0.0, open: 0.25, close: 0.75}]

    {:ok, output} =
      ExPostFacto.backtest(example_data, {Noop, :noop, []})

    assert example_data == output.data
  end

  test "backtest/3 returns an output struct with the strategy" do
    example_data = [%{high: 1.0, low: 0.0, open: 0.25, close: 0.75}]
    mfa = {Noop, :noop, []}

    {:ok, output} =
      ExPostFacto.backtest(example_data, mfa)

    assert mfa == output.strategy
  end
end
