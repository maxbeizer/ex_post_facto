defmodule ExPostFacto.TradeStats.Duration do
  @moduledoc """
  A module for comparing dates.
  """

  @seconds_in_a_day 86400

  @doc """
  Given a string representing a start and end date, return the number of days
  between the two points. Also handles DateTime structs.
  """
  @spec call!(start_date :: String.t() | DateTime.t(), end_date :: String.t() | DateTime.t()) :: number() | nil
  def call!(nil, nil), do: nil
  def call!(_, nil), do: nil
  def call!(nil, _), do: nil

  def call!(start_date, end_date) when is_binary(start_date) and is_binary(end_date) do
    with {:ok, start_date} <- Date.from_iso8601(start_date),
         {:ok, end_date} <- Date.from_iso8601(end_date) do
      Date.diff(end_date, start_date)
    else
      _ ->
        case {DateTime.from_iso8601(start_date), DateTime.from_iso8601(end_date)} do
          {{:ok, start_date_time, _}, {:ok, end_date_time, _}} ->
            if intraday?(start_date_time, end_date_time) do
              DateTime.diff(end_date_time, start_date_time, :second) / @seconds_in_a_day
            else
              DateTime.diff(end_date_time, start_date_time, :day)
            end

          _ ->
            nil
        end
    end
  end

  def call!(%DateTime{} = start_date, %DateTime{} = end_date) do
    if intraday?(start_date, end_date) do
      DateTime.diff(end_date, start_date, :second) / @seconds_in_a_day
    else
      DateTime.diff(end_date, start_date, :day)
    end
  end

  def call!(start_date, end_date) when is_binary(start_date) and is_struct(end_date, DateTime) do
    call!(start_date, DateTime.to_iso8601(end_date))
  end

  def call!(start_date, end_date) when is_struct(start_date, DateTime) and is_binary(end_date) do
    call!(DateTime.to_iso8601(start_date), end_date)
  end

  @spec intraday?(DateTime.t(), DateTime.t()) :: boolean()
  defp intraday?(start_date_time, end_date_time) do
    Date.diff(end_date_time, start_date_time) == 0
  end
end
