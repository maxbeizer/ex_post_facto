defmodule ExPostFacto.Result do
  @moduledoc """
  The result contains the output of applying a strategy to a set of data.
  """

  defstruct data_points: [], total_profit_and_loss: 0.0, max_draw_down: 0.0

  @doc """
  Creates a new result struct.
  """
  @spec new() :: %__MODULE__{}
  def new() do
    %__MODULE__{}
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

    %{result | data_points: [data_point | result.data_points]}
  end

  @spec compile(%__MODULE__{}) :: %__MODULE__{}
  def compile(result), do: result
end
