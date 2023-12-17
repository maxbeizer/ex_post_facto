defmodule ExPostFactoInputDataTest do
  use ExUnit.Case, async: true

  alias ExPostFacto.InputData

  test "new!/6 returns a new input_data struct" do
    assert %InputData{} =
             InputData.new!(%{
               high: 1.0,
               low: 1.0,
               open: 1.0,
               close: 1.0,
               volume: 1.0,
               timestamp: "2018-01-01"
             })
  end

  test "new!/6 handles when input has all data in the input map" do
    result =
      InputData.new!(%{
        high: 1.0,
        low: 1.0,
        open: 1.0,
        close: 1.0,
        volume: 1.0,
        timestamp: "2018-01-01"
      })

    assert 1.0 == result.high
    assert 1.0 == result.low
    assert 1.0 == result.open
    assert 1.0 == result.close
    assert 1.0 == result.volume
    assert "2018-01-01" == result.timestamp
  end

  test "new!/6 raises without required input" do
    assert_raise InputData.InvalidInputDataError, fn ->
      InputData.new!(%{
        high: 1.0,
        low: 1.0,
        open: 1.0,
        close: 1.0,
        volume: 1.0
      })
    end
  end

  test "munge/1 returns a new input_data struct with all data" do
    result =
      InputData.munge(%{
        high: 1.0,
        low: 1.0,
        open: 1.0,
        close: 1.0,
        volume: 1.0,
        timestamp: "2018-01-01"
      })

    assert %InputData{} = result
  end

  test "munge/1 returns a new input_data struct without timestamp" do
    result =
      InputData.munge(%{
        high: 1.0,
        low: 1.0,
        open: 1.0,
        close: 1.0,
        volume: 1.0
      })

    assert %InputData{} = result
  end

  test "munge/1 returns a new input_data struct without volume and timestamp" do
    result =
      InputData.munge(%{
        high: 1.0,
        low: 1.0,
        open: 1.0,
        close: 1.0
      })

    assert %InputData{} = result
  end

  test "munge/1 handles hlocvt maps" do
    result =
      InputData.munge(%{
        h: 1.0,
        l: 1.0,
        o: 1.0,
        c: 1.0,
        v: 1.0,
        t: "2018-01-01"
      })

    assert %InputData{} = result
  end

  test "munge/1 handles hlocv maps" do
    result =
      InputData.munge(%{
        h: 1.0,
        l: 1.0,
        o: 1.0,
        c: 1.0,
        v: 1.0
      })

    assert %InputData{} = result
  end

  test "munge/1 handles hloc maps without v and t" do
    result =
      InputData.munge(%{
        h: 1.0,
        l: 1.0,
        o: 1.0,
        c: 1.0
      })

    assert %InputData{} = result
  end

  @tag :foo
  test "munge/1 handles high low open close timestamp other maps" do
    result =
      InputData.munge(%{
        high: 1.0,
        low: 1.0,
        open: 1.0,
        close: 1.0,
        timestamp: "2018-01-01",
        other: "other"
      })

    assert %InputData{
             high: 1.0,
             low: 1.0,
             open: 1.0,
             close: 1.0,
             volume: nil,
             timestamp: "2018-01-01",
             other: "other"
           } == result
  end

  test "munge/1 handles high low open close volume timestamp other maps" do
    result =
      InputData.munge(%{
        high: 1.0,
        low: 1.0,
        open: 1.0,
        close: 1.0,
        volume: 1.0,
        timestamp: "2018-01-01",
        other: "other"
      })

    assert %InputData{
             high: 1.0,
             low: 1.0,
             open: 1.0,
             close: 1.0,
             volume: 1.0,
             timestamp: "2018-01-01",
             other: "other"
           } == result
  end

  test "munge/1 handles hlocvt other maps" do
    result =
      InputData.munge(%{
        h: 1.0,
        l: 1.0,
        o: 1.0,
        c: 1.0,
        v: 1.0,
        t: "2018-01-01",
        other: "other"
      })

    assert %InputData{
             high: 1.0,
             low: 1.0,
             open: 1.0,
             close: 1.0,
             volume: 1.0,
             timestamp: "2018-01-01",
             other: "other"
           } == result
  end
end
