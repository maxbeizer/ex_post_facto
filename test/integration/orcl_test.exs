defmodule Integration.OrclTest do
  use ExUnit.Case, async: true
  alias Integration.OrclTest.Strategy

  @tag :integration
  test "it works end to end" do
    {:ok, result} =
      "test/fixtures/orcl-1995-2014.txt"
      |> File.read!()
      |> convert_to_expf_data()
      |> ExPostFacto.backtest({Strategy, :call, []})

    assert result
  end

  defmodule Strategy do
    def call(
          %{
            close: current_close,
            other: %{previous_one: previous_one, previous_two: previous_two}
          },
          result
        ) do
      cond do
        result.is_position_open ->
          :close_buy

        previous_one.close < previous_two.close and previous_two.close < current_close ->
          :buy

        true ->
          nil
      end
    end
  end

  defp convert_to_expf_data(data) do
    data
    |> String.split("\n")
    |> Enum.drop(1)
    |> Enum.reject(&String.equivalent?(String.trim(&1), ""))
    |> Enum.chunk_every(3, 1, :discard)
    |> Enum.map(fn [previous_two, previous_one, current] ->
      [date, open, high, low, close, _adj, volume] = String.split(current, ",")

      [
        previous_one_date,
        previous_one_open,
        previous_one_high,
        previous_one_low,
        previous_one_close,
        _adj,
        previous_one_volume
      ] = String.split(previous_one, ",")

      [
        previous_two_date,
        previous_two_open,
        previous_two_high,
        previous_two_low,
        previous_two_close,
        _adj,
        previous_two_volume
      ] = String.split(previous_two, ",")

      %{
        t: date,
        o: String.to_float(open),
        h: String.to_float(high),
        l: String.to_float(low),
        c: String.to_float(close),
        v: String.to_integer(volume),
        other: %{
          previous_one: %{
            t: previous_one_date,
            o: String.to_float(previous_one_open),
            h: String.to_float(previous_one_high),
            l: String.to_float(previous_one_low),
            close: String.to_float(previous_one_close),
            v: String.to_integer(previous_one_volume)
          },
          previous_two: %{
            t: previous_two_date,
            o: String.to_float(previous_two_open),
            h: String.to_float(previous_two_high),
            l: String.to_float(previous_two_low),
            close: String.to_float(previous_two_close),
            v: String.to_integer(previous_two_volume)
          }
        }
      }
    end)
  end
end
