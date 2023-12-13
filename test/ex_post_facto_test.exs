defmodule ExPostFactoTest do
  use ExUnit.Case, async: true
  doctest ExPostFacto

  alias ExPostFacto.{
    Noop,
    Output
  }

  test "backtest/3 returns an error when data is nil" do
    assert {:error, "data cannot be nil"} = ExPostFacto.backtest(nil, {Noop, :noop, []})
  end

  test "backtest/3 returns an error when strategy is nil" do
    assert {:error, "strategy cannot be nil"} = ExPostFacto.backtest([], nil)
  end

  test "backtest/3 returns an output struct" do
    assert {:ok, %Output{}} = ExPostFacto.backtest([], {Noop, :noop, []})
  end
end
