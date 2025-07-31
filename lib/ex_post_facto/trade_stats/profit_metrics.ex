defmodule ExPostFacto.TradeStats.ProfitMetrics do
  @moduledoc """
  Calculates profit-related metrics for trading performance analysis.

  This module provides calculations for:
  - Profit Factor: Ratio of gross profit to gross loss
  - Expectancy: Average expected return per trade
  - Expectancy Percentage: Average expected return per trade as percentage
  """

  alias ExPostFacto.Result
  alias ExPostFacto.TradeStats.TradePair

  @doc """
  Calculates the profit factor.

  Profit Factor = Gross Profit / |Gross Loss|

  A profit factor > 1.0 indicates a profitable strategy.
  A profit factor of 2.0 means the strategy makes $2 for every $1 lost.
  """
  @spec profit_factor(result :: %Result{}) :: float()
  def profit_factor(result) do
    {gross_profit, gross_loss} = gross_profit_and_loss(result)

    cond do
      abs(gross_loss) == 0.0 and gross_profit == 0.0 -> 0.0
      abs(gross_loss) == 0.0 -> :infinity
      true -> gross_profit / abs(gross_loss)
    end
  end

  @doc """
  Calculates the expectancy (average profit/loss per trade).

  Expectancy = Total Profit / Number of Trades
  """
  @spec expectancy(result :: %Result{}) :: float()
  def expectancy(%{trades_count: 0}), do: 0.0

  def expectancy(result) do
    result.total_profit_and_loss / result.trades_count
  end

  @doc """
  Calculates the expectancy as a percentage of the starting balance.

  Expectancy % = (Expectancy / Starting Balance) * 100
  """
  @spec expectancy_percentage(result :: %Result{}) :: float()
  def expectancy_percentage(%{starting_balance: starting_balance}) when starting_balance == 0.0,
    do: 0.0

  def expectancy_percentage(result) do
    expectancy_value = expectancy(result)
    expectancy_value / result.starting_balance * 100
  end

  @doc """
  Calculates gross profit and gross loss separately.

  Returns a tuple {gross_profit, gross_loss} where:
  - gross_profit is the sum of all profitable trades
  - gross_loss is the sum of all losing trades (negative value)
  """
  @spec gross_profit_and_loss(result :: %Result{}) :: {float(), float()}
  def gross_profit_and_loss(result) do
    result.trade_pairs
    |> Enum.map(&TradePair.result_value/1)
    |> Enum.reduce({0.0, 0.0}, fn trade_result, {profit_acc, loss_acc} ->
      if trade_result > 0 do
        {profit_acc + trade_result, loss_acc}
      else
        {profit_acc, loss_acc + trade_result}
      end
    end)
  end

  @doc """
  Calculates the average winning trade amount.
  """
  @spec average_winning_trade(result :: %Result{}) :: float()
  def average_winning_trade(result) do
    winning_trades =
      result.trade_pairs
      |> Enum.map(&TradePair.result_value/1)
      |> Enum.filter(fn value -> value > 0 end)

    case length(winning_trades) do
      0 -> 0.0
      count -> Enum.sum(winning_trades) / count
    end
  end

  @doc """
  Calculates the average losing trade amount.
  """
  @spec average_losing_trade(result :: %Result{}) :: float()
  def average_losing_trade(result) do
    losing_trades =
      result.trade_pairs
      |> Enum.map(&TradePair.result_value/1)
      |> Enum.filter(fn value -> value < 0 end)

    case length(losing_trades) do
      0 -> 0.0
      count -> Enum.sum(losing_trades) / count
    end
  end

  @doc """
  Calculates the largest winning trade.
  """
  @spec largest_winning_trade(result :: %Result{}) :: float()
  def largest_winning_trade(result) do
    result.trade_pairs
    |> Enum.map(&TradePair.result_value/1)
    |> Enum.filter(fn value -> value > 0 end)
    |> case do
      [] -> 0.0
      winning_trades -> Enum.max(winning_trades)
    end
  end

  @doc """
  Calculates the largest losing trade.
  """
  @spec largest_losing_trade(result :: %Result{}) :: float()
  def largest_losing_trade(result) do
    result.trade_pairs
    |> Enum.map(&TradePair.result_value/1)
    |> Enum.filter(fn value -> value < 0 end)
    |> case do
      [] -> 0.0
      losing_trades -> Enum.min(losing_trades)
    end
  end
end
