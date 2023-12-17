defmodule Integration.OrclTest do
  use ExUnit.Case, async: true

  @tag :integration
  test "truth" do
    result =
      "test/fixtures/orcl-1995-2014.txt"
      |> File.read!()
      |> convert_to_expf_data()

    assert %{h: 2.191358} = Enum.at(result, 0)
  end

  defp convert_to_expf_data(data) do
    data
    |> String.split("\n")
    |> Enum.drop(1)
    |> Enum.reject(&String.equivalent?(String.trim(&1), ""))
    |> Enum.map(fn line ->
      [date, open, high, low, close, _adj, volume] = String.split(line, ",")

      %{
        timestamp: date,
        o: String.to_float(open),
        h: String.to_float(high),
        l: String.to_float(low),
        c: String.to_float(close),
        v: String.to_integer(volume)
      }
    end)
  end
end
