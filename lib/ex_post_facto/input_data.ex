defmodule ExPostFacto.InputData do
  @moduledoc """
  InputData a wrapper around the HLOC data that is passed into the backtest.
  """

  @enforce_keys [:high, :low, :open, :close, :volume, :timestamp]
  defstruct high: 0.0,
            low: 0.0,
            open: 0.0,
            close: 0.0,
            volume: 0.0,
            timestamp: nil,
            other: nil

  defmodule InvalidInputDataError do
    defexception message: "Invalid InputData"
  end

  @doc """
  Creates a new! InputData struct.
  """
  @spec new!(%{
          optional(:other) => any(),
          high: float(),
          low: float(),
          open: float(),
          close: float(),
          volume: float() | nil,
          timestamp: String.t() | nil
        }) :: %__MODULE__{}

  def new!(%{high: h, low: l, open: o, close: c, volume: v, timestamp: t, other: other}) do
    # TODO convert timestamp to DateTime
    %__MODULE__{
      high: h,
      low: l,
      open: o,
      close: c,
      volume: v,
      timestamp: t,
      other: other
    }
  end

  def new!(%{high: h, low: l, open: o, close: c, volume: v, timestamp: t}) do
    # TODO convert timestamp to DateTime
    %__MODULE__{
      high: h,
      low: l,
      open: o,
      close: c,
      volume: v,
      timestamp: t
    }
  end

  def new!(_), do: raise(InvalidInputDataError)

  @spec munge(%{
          optional(:high) => float(),
          optional(:h) => float(),
          optional(:low) => float(),
          optional(:l) => float(),
          optional(:open) => float(),
          optional(:o) => float(),
          optional(:close) => float(),
          optional(:c) => float(),
          optional(:timestamp) => float(),
          optional(:t) => float(),
          optional(:volume) => float(),
          optional(:v) => float(),
          optional(:other) => any()
        }) :: %__MODULE__{}
  def munge(data) do
    high = Map.get(data, :high) || Map.get(data, :h)
    low = Map.get(data, :low) || Map.get(data, :l)
    open = Map.get(data, :open) || Map.get(data, :o)
    close = Map.get(data, :close) || Map.get(data, :c)
    volume = Map.get(data, :volume) || Map.get(data, :v)
    timestamp = Map.get(data, :timestamp) || Map.get(data, :t)
    other = Map.get(data, :other)

    %__MODULE__{
      high: high,
      low: low,
      open: open,
      close: close,
      timestamp: timestamp,
      volume: volume,
      other: other
    }
  end
end
