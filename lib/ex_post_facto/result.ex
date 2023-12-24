defmodule ExPostFacto.Result do
  @moduledoc """
  The result contains the output of applying a strategy to a set of data.
  """
  alias ExPostFacto.DataPoint

  alias ExPostFacto.TradeStats.{
    Duration,
    TradePercentage,
    CompilePairs,
    TotalProfitAndLoss,
    WinRate
  }

  # TODOs:
  # - make this concurrent
  # - fill out data similar to backtesting output
  # Start                     2004-08-19 00:00:00
  # End                       2013-03-01 00:00:00
  # Duration                   3116 days 00:00:00
  # Exposure Time [%]                       94.27
  # Equity Final [$]                     68935.12
  # Equity Peak [$]                      68991.22
  # Return [%]                             589.35
  # Buy & Hold Return [%]                  703.46
  # Return (Ann.) [%]                       25.42
  # Volatility (Ann.) [%]                   38.43
  # Sharpe Ratio                             0.66
  # Sortino Ratio                            1.30
  # Calmar Ratio                             0.77
  # Max. Drawdown [%]                      -33.08
  # Avg. Drawdown [%]                       -5.58
  # Max. Drawdown Duration      688 days 00:00:00
  # Avg. Drawdown Duration       41 days 00:00:00
  # # Trades                                   93
  # Win Rate [%]                            53.76
  # Best Trade [%]                          57.12
  # Worst Trade [%]                        -16.63
  # Avg. Trade [%]                           1.96
  # Max. Trade Duration         121 days 00:00:00
  # Avg. Trade Duration          32 days 00:00:00
  # Profit Factor                            2.13
  # Expectancy [%]                           6.91
  # SQN                                      1.78
  # _strategy              SmaCross(n1=10, n2=20)

  defstruct data_points: [],
            is_position_open: false,
            starting_balance: 0.0,
            total_profit_and_loss: 0.0,
            max_draw_down: 0.0,
            start_date: nil,
            end_date: nil,
            duration: nil,
            trades_count: 0,
            win_rate: 0.0,
            trade_pairs: [],
            best_trade_by_percentage: 0.0,
            worst_trade_by_percentage: 0.0,
            average_trade_by_percentage: 0.0

  @doc """
  Creates a new result struct.
  """
  @spec new(
          starting_balance: float(),
          start_date: String.t(),
          end_date: String.t()
        ) :: %__MODULE__{}
  def new(options \\ []) do
    starting_balance = Keyword.get(options, :starting_balance, 0.0)
    start_date = Keyword.get(options, :start_date)
    end_date = Keyword.get(options, :end_date)

    %__MODULE__{
      starting_balance: starting_balance,
      start_date: start_date,
      end_date: end_date,
      duration: Duration.call!(start_date, end_date)
    }
  end

  @spec add_data_point(
          result :: %__MODULE__{},
          index :: integer(),
          datum :: map(),
          action :: ExPostFacto.action()
        ) :: %__MODULE__{}
  def add_data_point(result, index, datum, action) do
    data_point = DataPoint.new(datum, action, index)

    case add_data_point?(result, action) do
      true ->
        update_result(result, data_point, action)

      false ->
        result
    end
  end

  @spec update_result(
          result :: %__MODULE__{},
          data_point :: %DataPoint{},
          action :: ExPostFacto.action()
        ) :: %__MODULE__{}
  defp update_result(result, data_point, action) do
    %{
      result
      | data_points: [data_point | result.data_points],
        is_position_open: position_open?(action),
        trades_count: calculate_trade_count(result, action)
    }
  end

  @spec compile(result :: %__MODULE__{}, options :: keyword()) :: %__MODULE__{}
  def compile(result, options \\ [])

  def compile(result, _options) do
    trade_stats =
      result
      |> close_maybe_dangling_open_trade()
      |> CompilePairs.call!()
      |> calculate_trade_stats!()

    Enum.into(trade_stats, result)
  end

  @spec add_data_point?(result :: %__MODULE__{}, action :: ExPostFacto.action()) :: boolean()
  defp add_data_point?(%{is_position_open: true}, :close_buy), do: true
  defp add_data_point?(%{is_position_open: true}, :close_sell), do: true
  defp add_data_point?(%{is_position_open: true}, _), do: false
  defp add_data_point?(%{is_position_open: false}, :close_buy), do: false
  defp add_data_point?(%{is_position_open: false}, :close_sell), do: false
  defp add_data_point?(%{is_position_open: false}, _), do: true

  @spec position_open?(action :: ExPostFacto.action()) :: boolean()
  defp position_open?(:close_buy), do: false
  defp position_open?(:close_sell), do: false
  defp position_open?(_), do: true

  @spec calculate_trade_stats!(result :: %__MODULE__{}) :: keyword() | no_return()
  defp calculate_trade_stats!(result) do
    [
      {:trade_pairs, result.trade_pairs},
      {:total_profit_and_loss, TotalProfitAndLoss.calculate!(result.data_points, 0.0)},
      {:win_rate, WinRate.calculate!(result)},
      {:best_trade_by_percentage, TradePercentage.best!(result)},
      {:worst_trade_by_percentage, TradePercentage.worst!(result)},
      {:average_trade_by_percentage, TradePercentage.average!(result)}
    ]
  end

  defp calculate_trade_count(result, :close_buy), do: result.trades_count + 1
  defp calculate_trade_count(result, :close_sell), do: result.trades_count + 1
  defp calculate_trade_count(result, _), do: result.trades_count

  defmodule ResultCalculationError, do: defexception(message: "Error calculating result")

  defimpl Collectable, for: ExPostFacto.Result do
    @spec into(result :: struct()) :: {struct(), (any(), :done | :halt | {any(), any()} -> any())}
    def into(result) do
      collector_fun = fn
        result_struct, {:cont, {k, v}} ->
          Map.replace(result_struct, k, v)

        result_struct, :done ->
          result_struct

        _result_struct, :halt ->
          :ok
      end

      initial_acc = result

      {initial_acc, collector_fun}
    end
  end

  @spec close_maybe_dangling_open_trade(result :: %__MODULE__{}) :: %__MODULE__{}
  defp close_maybe_dangling_open_trade(
         %{data_points: [%{datum: datum, action: :buy, index: index} = dangler | rest]} = result
       ) do
    %{
      result
      | data_points: [
          %DataPoint{datum: datum, action: :close_buy, index: index + 1},
          dangler | rest
        ],
        trades_count: result.trades_count + 1
    }
  end

  defp close_maybe_dangling_open_trade(
         %{data_points: [%{datum: datum, action: :sell, index: index} = dangler | rest]} = result
       ) do
    %{
      result
      | data_points: [
          %DataPoint{datum: datum, action: :close_sell, index: index + 1},
          dangler | rest
        ],
        trades_count: result.trades_count + 1
    }
  end

  defp close_maybe_dangling_open_trade(result), do: result
end
