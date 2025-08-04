defmodule ExPostFacto.TradeStats.TradePair do
  @moduledoc """
  Given a list of data points, group the enter and exit points into pairs with
  metadata.
  """

  alias ExPostFacto.DataPoint

  alias ExPostFacto.TradeStats.{
    Duration,
    TotalProfitAndLoss
  }

  @enforce_keys [:exit_point, :enter_point, :balance, :previous_balance]
  defstruct [:exit_point, :enter_point, :balance, :previous_balance]

  @type t :: %__MODULE__{
          exit_point: DataPoint.t(),
          enter_point: DataPoint.t(),
          balance: float(),
          previous_balance: float()
        }

  @doc """
  Builds a new trade pair struct.
  """
  @spec new(DataPoint.t(), DataPoint.t(), float()) :: %__MODULE__{}
  def new(exit_point, enter_point, previous_balance) do
    %__MODULE__{
      exit_point: exit_point,
      enter_point: enter_point,
      balance: TotalProfitAndLoss.calculate!([exit_point, enter_point], previous_balance),
      previous_balance: previous_balance
    }
  end

  @doc """
  Returns the result of the trade pair as an atom, :win, :loss, or :break_even.
  """
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

  @doc """
  Returns the result of the trade pair as a float representing profit or loss.
  """
  @spec result_value(%__MODULE__{}) :: float()
  def result_value(%{
        exit_point: %{datum: %{open: exit_price}},
        enter_point: %{datum: %{open: enter_price}, action: :buy}
      }) do
    exit_price - enter_price
  end

  @spec result_value(%__MODULE__{}) :: float()
  def result_value(%{
        exit_point: %{datum: %{open: exit_price}},
        enter_point: %{datum: %{open: enter_price}, action: :sell}
      }) do
    enter_price - exit_price
  end

  @doc """
  Returns the result of the trade pair as a float representing profit or loss as
  a percentage of the balance before the trade.
  """
  @spec result_percentage(%__MODULE__{}) :: float()
  def result_percentage(%{previous_balance: previous_balance}) when previous_balance == 0.0,
    do: 0.0

  def result_percentage(%{
        exit_point: %{datum: %{open: exit_price}},
        enter_point: %{datum: %{open: enter_price}, action: :buy},
        previous_balance: previous_balance
      }) do
    100 * (exit_price - enter_price) / previous_balance
  end

  def result_percentage(%{
        exit_point: %{datum: %{open: exit_price}},
        enter_point: %{datum: %{open: enter_price}, action: :sell},
        previous_balance: previous_balance
      }) do
    100 * (enter_price - exit_price) / previous_balance
  end

  @doc """
  Return the duration of the trade pair in days.
  """
  @spec duration(%__MODULE__{}) :: float()
  def duration(%{
        exit_point: %{datum: %{timestamp: exit_timestamp}},
        enter_point: %{datum: %{timestamp: enter_timestamp}}
      })
      when not is_nil(exit_timestamp) and not is_nil(enter_timestamp) do
    # handle when timestamps are empty strings by returning 0.0
    Duration.call!(enter_timestamp, exit_timestamp) || 0.0
  end

  def duration(%{
        exit_point: %{datum: %{timestamp: nil}},
        enter_point: %{datum: %{timestamp: nil}}
      }) do
    0.0
  end

  def duration(_), do: 0.0
end
