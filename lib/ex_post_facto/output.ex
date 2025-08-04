defmodule ExPostFacto.Output do
  @moduledoc """
  The output is what is returned from the backtest function.
  """

  alias ExPostFacto.{
    DataPoint,
    Result
  }

  defstruct data: [], strategy: nil, result: nil

  @type t :: %__MODULE__{
          data: [DataPoint.t()],
          strategy: ExPostFacto.module_function_arguments(),
          result: Result.t()
        }

  @doc """
  Creates a new output struct.
  """
  @spec new(
          data :: [DataPoint.t()],
          strategy :: ExPostFacto.module_function_arguments(),
          result :: Result.t()
        ) :: %__MODULE__{}
  def new(data, strategy, result) do
    %__MODULE__{
      data: data,
      strategy: strategy,
      result: result
    }
  end
end
