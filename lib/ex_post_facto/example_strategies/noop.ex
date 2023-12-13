defmodule ExPostFacto.ExampleStrategies.Noop do
  @moduledoc false

  @doc false
  @spec noop(any()) :: :noop
  def noop(_datum), do: :noop
end
