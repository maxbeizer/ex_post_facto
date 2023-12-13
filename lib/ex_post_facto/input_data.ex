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
            timestamp: nil

  defmodule InvalidInputDataError do
    defexception message: "Invalid InputData"
  end

  @doc """
  Creates a new! InputData struct.
  """
  @spec new!(%{
          high: float(),
          low: float(),
          open: float(),
          close: float(),
          volume: float() | nil,
          timestamp: String.t() | nil
        }) :: %__MODULE__{}
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

  @spec munge(map()) :: %__MODULE__{}
  def munge(%{
        high: high,
        low: low,
        open: open,
        close: close,
        volume: volume,
        timestamp: timestamp
      }) do
    new!(%{
      high: high,
      low: low,
      open: open,
      close: close,
      volume: volume,
      timestamp: timestamp
    })
  end

  def munge(%{
        high: high,
        low: low,
        open: open,
        close: close,
        volume: volume
      }) do
    new!(%{
      high: high,
      low: low,
      open: open,
      close: close,
      volume: volume,
      timestamp: nil
    })
  end

  def munge(%{
        high: high,
        low: low,
        open: open,
        close: close
      }) do
    new!(%{
      high: high,
      low: low,
      open: open,
      close: close,
      volume: nil,
      timestamp: nil
    })
  end

  def munge(%{
        h: high,
        l: low,
        o: open,
        c: close
      }) do
    new!(%{
      high: high,
      low: low,
      open: open,
      close: close,
      volume: nil,
      timestamp: nil
    })
  end

  def munge(%{
        h: high,
        l: low,
        o: open,
        c: close,
        v: volume
      }) do
    new!(%{
      high: high,
      low: low,
      open: open,
      close: close,
      volume: volume,
      timestamp: nil
    })
  end

  def munge(%{
        h: high,
        l: low,
        o: open,
        c: close,
        v: volume,
        t: timestamp
      }) do
    new!(%{
      high: high,
      low: low,
      open: open,
      close: close,
      volume: volume,
      timestamp: timestamp
    })
  end
end
