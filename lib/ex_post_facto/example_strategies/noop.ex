defmodule ExPostFacto.ExampleStrategies.Noop do
  @moduledoc false

  @doc false
  @spec noop(any(), any() | nil) :: :noop
  def noop(_datum, _result), do: :noop
end
