defmodule ExPostFacto.TradeStats.DrawDown do
  @moduledoc """
  Calculate the draw down from trade pairs.

  Example:
  Max. Drawdown [%]                      -33.08
  Avg. Drawdown [%]                       -5.58
  Max. Drawdown Duration      688 days 00:00:00
  Avg. Drawdown Duration       41 days 00:00:00
  """

  alias ExPostFacto.TradeStats.Duration

  defstruct peak: 0,
            peak_time: nil,
            drawdown_percentage: 0,
            drawdown_sum: 0,
            drawdown_count: 0,
            max_duration: 0,
            total_duration: 0,
            max_percentage: 0,
            average_percentage: 0,
            average_duration: 0,
            previous_drawdown_percentage: 0

  @spec call!(%{trade_pairs: [TradePair.t()]}) :: %__MODULE__{}
  def call!(%{trade_pairs: []}), do: %__MODULE__{}

  def call!(%{trade_pairs: trade_pairs}) do
    drawdown =
      Enum.reduce(trade_pairs, %__MODULE__{}, fn trade_pair, acc ->
        %{balance: balance, exit_point: exit_point} = trade_pair
        %{datum: %{timestamp: timestamp}} = exit_point

        %{
          peak: peak,
          drawdown_percentage: drawdown_percentage,
          drawdown_sum: drawdown_sum,
          drawdown_count: drawdown_count,
          max_duration: max_duration,
          total_duration: total_duration
        } = acc

        previous_drawdown_percentage =
          if peak == 0,
            do: 0,
            else: (peak - balance) / peak * 100.0

        acc = calculate_peak(acc, trade_pair)
        %{peak: peak, peak_time: peak_time} = acc

        current_drawdown_percentage =
          if balance < peak, do: (peak - balance) / peak * 100.0, else: 0.0

        drawdown_sum = drawdown_sum + current_drawdown_percentage

        drawdown_count =
          if current_drawdown_percentage > 0, do: drawdown_count + 1, else: drawdown_count

        duration =
          if peak_time != nil and current_drawdown_percentage != 0,
            do: Duration.call!(peak_time, timestamp),
            else: 0

        total_duration = total_duration + duration

        max_duration = max(max_duration || 0, duration)

        max_percentage =
          if current_drawdown_percentage == 0,
            do: max(drawdown_percentage, previous_drawdown_percentage),
            else: current_drawdown_percentage

        %{
          acc
          | peak: peak,
            max_percentage: max_percentage,
            drawdown_sum: drawdown_sum,
            drawdown_count: drawdown_count,
            max_duration: max_duration,
            total_duration: total_duration
        }
      end)

    %{
      drawdown_sum: drawdown_sum,
      drawdown_count: drawdown_count,
      total_duration: total_duration
    } = drawdown

    average_duration = if drawdown_count > 0, do: total_duration / drawdown_count, else: 0.0
    average_percentage = if drawdown_count > 0, do: drawdown_sum / drawdown_count, else: 0.0

    %{
      drawdown
      | average_duration: average_duration,
        average_percentage: average_percentage
    }
  end

  defp calculate_peak(%{peak: 0} = acc, trade_pair) do
    %{balance: balance, exit_point: exit_point} = trade_pair
    %{datum: %{timestamp: timestamp}} = exit_point
    %{acc | peak: balance, peak_time: timestamp}
  end

  defp calculate_peak(%{peak: peak} = acc, %{balance: balance} = trade_pair)
       when balance > peak do
    %{exit_point: exit_point} = trade_pair
    %{datum: %{timestamp: timestamp}} = exit_point
    %{acc | peak: balance, peak_time: timestamp}
  end

  defp calculate_peak(acc, _), do: acc
end
