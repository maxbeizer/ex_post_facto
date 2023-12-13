defmodule ExPostFacto.DataPoint do
  @moduledoc """
  DataPoint is a wrapper around data that represents an action taken, e.g. a buy or a sell.
  """

  @enforce_keys [:datum, :action, :index]
  defstruct [:datum, :action, :index]

  @doc """
  Creates a new data point struct.
  """
  @spec new(datum :: map(), action :: atom(), index :: integer()) :: %__MODULE__{}
  def new(datum, action, index) do
    %__MODULE__{datum: datum, action: action, index: index}
  end
end
