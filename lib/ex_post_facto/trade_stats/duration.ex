defmodule ExPostFacto.TradeStats.Duration do
  @moduledoc """
  A module for comparing dates.
  """

  @doc """
  Given a string representing a start and end date, return the number of days
  between the two points.
  """
  @spec call!(start_date :: String.t(), end_date :: String.t()) :: number() | nil
  def call!(nil, nil), do: nil
  def call!(_, nil), do: nil
  def call!(nil, _), do: nil

  def call!(start_date, end_date) do
    with {:ok, start_date} <- Date.from_iso8601(start_date),
         {:ok, end_date} <- Date.from_iso8601(end_date) do
      Date.diff(end_date, start_date)
    else
      _ ->
        case {DateTime.from_iso8601(start_date), DateTime.from_iso8601(end_date)} do
          {{:ok, start_date_time, _}, {:ok, end_date_time, _}} ->
            if intraday?(start_date_time, end_date_time) do
              DateTime.diff(end_date_time, start_date_time, :hour) / 24
            else
              DateTime.diff(end_date_time, start_date_time, :day)
            end

          _ ->
            nil
        end
    end
  end

  @spec intraday?(DateTime.t(), DateTime.t()) :: boolean()
  defp intraday?(start_date_time, end_date_time) do
    Date.diff(end_date_time, start_date_time) == 0
  end
end
