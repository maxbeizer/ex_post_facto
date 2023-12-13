defmodule ExPostFacto.Result do
  @moduledoc """
  The result contains the output of applying a strategy to a set of data.
  """

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
            max_draw_down: 0.0

  @doc """
  Creates a new result struct.
  """
  @spec new(starting_balance :: float()) :: %__MODULE__{}
  def new(starting_balance) do
    %__MODULE__{
      starting_balance: starting_balance
    }
  end

  @spec add_data_point(
          result :: %__MODULE__{},
          index :: integer(),
          datum :: map(),
          action :: atom()
        ) :: %__MODULE__{}
  def add_data_point(result, index, datum, action) do
    data_point = %{
      index: index,
      datum: datum,
      action: action
    }

    case should_add_data_point?(result, action) do
      true ->
        update_result(result, data_point, action)

      false ->
        result
    end
  end

  defp update_result(result, data_point, action) do
    %{
      result
      | data_points: [data_point | result.data_points],
        is_position_open: is_position_open?(action)
    }
  end

  @spec compile(result :: %__MODULE__{}, options :: keyword()) :: %__MODULE__{}
  def compile(result, _options) do
    %{result | total_profit_and_loss: calculate_profit_and_loss(result)}
  end

  defp should_add_data_point?(%{is_position_open: true}, :close), do: true
  defp should_add_data_point?(%{is_position_open: true}, _), do: false
  defp should_add_data_point?(%{is_position_open: false}, false), do: false
  defp should_add_data_point?(%{is_position_open: false}, _), do: true

  defp is_position_open?(:close), do: false
  defp is_position_open?(_), do: true

  @spec calculate_profit_and_loss(result :: %__MODULE__{}) :: float()
  defp calculate_profit_and_loss(result) do
    do_calculate_profit_and_loss(result.data_points, 0.0)
  end

  @spec do_calculate_profit_and_loss(
          data_points :: list(),
          total_profit_and_loss :: float()
        ) :: float()
  defp do_calculate_profit_and_loss([], total_profit_and_loss), do: total_profit_and_loss

  defp do_calculate_profit_and_loss(data, total_profit_and_loss) when length(data) == 1,
    do: total_profit_and_loss

  defp do_calculate_profit_and_loss([head, previous | rest], total_profit_and_loss) do
    %{datum: %{close: head_close}, action: head_action} = head
    %{datum: %{close: previous_close}, action: previous_action} = previous

    computed_profit_and_loss =
      cond do
        head_action == :close and previous_action == :buy and head_close > previous_close ->
          total_profit_and_loss + head_close + previous_close

        head_action == :close and previous_action == :buy and head_close < previous_close ->
          total_profit_and_loss + head_close - previous_close

        head_action == :close and previous_action == :buy and head_close == previous_close ->
          total_profit_and_loss

        head_action == :close and previous_action == :sell and head_close > previous_close ->
          total_profit_and_loss + previous_close + head_close

        head_action == :close and previous_action == :sell and head_close < previous_close ->
          total_profit_and_loss + previous_close - head_close

        head_action == :close and previous_action == :sell and head_close == previous_close ->
          total_profit_and_loss

        true ->
          total_profit_and_loss
      end

    do_calculate_profit_and_loss(rest, computed_profit_and_loss)
  end
end
