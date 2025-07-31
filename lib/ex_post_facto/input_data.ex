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
          timestamp: String.t() | DateTime.t() | nil
        }) :: %__MODULE__{}

  def new!(%{high: h, low: l, open: o, close: c, volume: v, timestamp: t, other: other}) do
    %__MODULE__{
      high: h,
      low: l,
      open: o,
      close: c,
      volume: v,
      timestamp: normalize_timestamp(t),
      other: other
    }
  end

  def new!(%{high: h, low: l, open: o, close: c, volume: v, timestamp: t}) do
    %__MODULE__{
      high: h,
      low: l,
      open: o,
      close: c,
      volume: v,
      timestamp: normalize_timestamp(t)
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
          optional(:timestamp) => String.t() | DateTime.t(),
          optional(:t) => String.t() | DateTime.t(),
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
      timestamp: normalize_timestamp(timestamp),
      volume: volume,
      other: other
    }
  end

  @doc """
  Normalizes timestamp to a consistent format.

  Attempts to parse string timestamps into DateTime structs for better handling.
  """
  @spec normalize_timestamp(String.t() | DateTime.t() | nil) :: DateTime.t() | String.t() | nil
  def normalize_timestamp(nil), do: nil
  def normalize_timestamp(%DateTime{} = dt), do: dt
  def normalize_timestamp(timestamp) when is_binary(timestamp) do
    case parse_timestamp(timestamp) do
      {:ok, datetime} -> datetime
      {:error, _} -> timestamp  # Keep original if parsing fails
    end
  end
  def normalize_timestamp(timestamp), do: timestamp

  @spec parse_timestamp(String.t()) :: {:ok, DateTime.t()} | {:error, any()}
  defp parse_timestamp(timestamp_str) do
    # Try various common timestamp formats
    formats = [
      # ISO 8601 formats
      &DateTime.from_iso8601/1,
      # Date only formats
      fn str ->
        case Date.from_iso8601(str) do
          {:ok, date} -> {:ok, DateTime.new!(date, ~T[00:00:00])}
          error -> error
        end
      end,
      # Unix timestamp (if numeric string)
      fn str ->
        case Integer.parse(str) do
          {unix_time, ""} -> {:ok, DateTime.from_unix!(unix_time)}
          _ -> {:error, :invalid_unix_timestamp}
        end
      end
    ]

    # Try each format until one works
    Enum.reduce_while(formats, {:error, :no_format_matched}, fn parser, _acc ->
      case parser.(timestamp_str) do
        {:ok, datetime, _offset} -> {:halt, {:ok, datetime}}
        {:ok, datetime} -> {:halt, {:ok, datetime}}
        {:error, _} -> {:cont, {:error, :no_format_matched}}
      end
    end)
  end
end
