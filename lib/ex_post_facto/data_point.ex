defmodule ExPostFacto.DataPoint do
  @moduledoc """
  DataPoint is a wrapper around data that represents an action taken, e.g. a buy or a sell.
  """
  alias ExPostFacto.InputData

  @enforce_keys [:datum, :action, :index]
  defstruct [:datum, :action, :index]

  @type t :: %__MODULE__{
          datum: InputData.t(),
          action: atom(),
          index: integer()
        }

  @doc """
  Creates a new data point struct.
  """
  @spec new(datum :: InputData.t(), action :: atom(), index :: integer()) :: %__MODULE__{}
  def new(datum, action, index) do
    %__MODULE__{datum: datum, action: action, index: index}
  end
end
