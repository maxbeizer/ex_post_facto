defmodule ExPostFacto.TradeStats.TradePair do
  @moduledoc """
  Given a list of data points, group the enter and exit points into pairs with
  metadata.
  """

  alias ExPostFacto.DataPoint
  alias ExPostFacto.TradeStats.TotalProfitAndLoss

  @enforce_keys [:exit_point, :enter_point, :balance, :previous_balance]
  defstruct [:exit_point, :enter_point, :balance, :previous_balance]

  @spec new(DataPoint.t(), DataPoint.t(), float()) :: %__MODULE__{}
  def new(exit_point, enter_point, previous_balance) do
    %__MODULE__{
      exit_point: exit_point,
      enter_point: enter_point,
      balance: TotalProfitAndLoss.calculate!([exit_point, enter_point], previous_balance),
      previous_balance: previous_balance
    }
  end

  @spec result(%__MODULE__{}) :: :win | :loss | :break_even
  def result(%{
        exit_point: %{datum: %{open: exit_price}},
        enter_point: %{datum: %{open: enter_price}, action: :buy}
      }) do
    cond do
      exit_price > enter_price ->
        :win

      exit_price < enter_price ->
        :loss

      exit_price == enter_price ->
        :break_even
    end
  end

  def result(%{
        exit_point: %{datum: %{open: exit_price}},
        enter_point: %{datum: %{open: enter_price}, action: :sell}
      }) do
    cond do
      exit_price < enter_price ->
        :win

      exit_price > enter_price ->
        :loss

      exit_price == enter_price ->
        :break_even
    end
  end
end
