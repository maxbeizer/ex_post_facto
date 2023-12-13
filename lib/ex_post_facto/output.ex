defmodule ExPostFacto.Output do
  @moduledoc """
  The output is what is returned from the backtest function.
  """

  alias ExPostFacto.Result

  defstruct data: [], strategy: nil, result: nil

  @doc """
  Creates a new output struct.
  """
  @spec new(list(), mfa(), Result.t()) :: %__MODULE__{}
  def new(data, strategy, result) do
    %__MODULE__{
      data: data,
      strategy: strategy,
      result: result
    }
  end
end
