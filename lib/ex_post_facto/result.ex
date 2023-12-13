defmodule ExPostFacto.Result do
  @moduledoc """
  The result contains the output of applying a strategy to a set of data.
  """

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
        is_position_open: is_position_open?(action),
        total_profit_and_loss: calculate_profit_and_loss(result, data_point)
    }
  end

  @spec compile(%__MODULE__{}) :: %__MODULE__{}
  def compile(result), do: result

  defp should_add_data_point?(%{is_position_open: true}, :close), do: true
  defp should_add_data_point?(%{is_position_open: true}, _), do: false
  defp should_add_data_point?(%{is_position_open: false}, false), do: false
  defp should_add_data_point?(%{is_position_open: false}, _), do: true

  defp is_position_open?(:close), do: false
  defp is_position_open?(_), do: true

  @spec calculate_profit_and_loss(
          result :: %__MODULE__{},
          data_point :: map()
        ) :: float()
  defp calculate_profit_and_loss(%__MODULE__{data_points: []}, _), do: 0.0

  defp calculate_profit_and_loss(result, %{action: :close, datum: %{close: close}}) do
    do_calculate_profit_and_loss(result, close, hd(result.data_points))
  end

  defp calculate_profit_and_loss(result, _), do: result.total_profit_and_loss

  defp do_calculate_profit_and_loss(result, close, %{
         datum: %{close: previous_close},
         action: :buy
       })
       when close > previous_close do
    result.total_profit_and_loss + close + previous_close
  end

  defp do_calculate_profit_and_loss(result, close, %{datum: %{close: previous_close}})
       when close == previous_close do
    result.total_profit_and_loss
  end

  defp do_calculate_profit_and_loss(result, close, %{
         datum: %{close: previous_close},
         action: :buy
       })
       when close < previous_close do
    result.total_profit_and_loss + close - previous_close
  end

  defp do_calculate_profit_and_loss(result, close, %{
         datum: %{close: previous_close},
         action: :sell
       })
       when close < previous_close do
    result.total_profit_and_loss + previous_close + close
  end

  defp do_calculate_profit_and_loss(result, close, %{
         datum: %{close: previous_close},
         action: :sell
       })
       when close > previous_close do
    result.total_profit_and_loss + previous_close - close
  end
end
