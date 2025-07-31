defmodule ExPostFacto.StrategyContext do
  @moduledoc """
  Provides context and state management for enhanced strategies.

  This module manages the execution context for strategies using the 
  ExPostFacto.Strategy behaviour, providing access to current market data,
  equity, position state, and action handling.
  """

  use Agent

  alias ExPostFacto.Result

  @type context :: %{
          data: map(),
          result: Result.t(),
          action: ExPostFacto.action() | nil,
          equity: float(),
          position: :long | :short | :none
        }

  @doc """
  Start the strategy context for the current execution.
  """
  def start_link(initial_context \\ %{}) do
    Agent.start_link(fn -> initial_context end, name: __MODULE__)
  end

  @doc """
  Stop the strategy context.
  """
  def stop do
    if Process.whereis(__MODULE__) do
      Agent.stop(__MODULE__)
    end
  end

  @doc """
  Set the current context with market data and result state.
  """
  def set_context(data, result) do
    equity = calculate_equity(result)
    position = determine_position(result)

    context = %{
      data: data,
      result: result,
      action: nil,
      equity: equity,
      position: position
    }

    if Process.whereis(__MODULE__) do
      Agent.update(__MODULE__, fn _ -> context end)
    else
      {:ok, _pid} = start_link(context)
    end

    :ok
  end

  @doc """
  Set the action to be taken by the strategy.
  """
  def set_action(action) when action in [:buy, :sell, :close_buy, :close_sell] do
    if Process.whereis(__MODULE__) do
      Agent.update(__MODULE__, fn context ->
        Map.put(context, :action, action)
      end)
    end

    action
  end

  @doc """
  Get the current action set by the strategy.
  """
  def get_action do
    if Process.whereis(__MODULE__) do
      Agent.get(__MODULE__, fn context ->
        Map.get(context, :action)
      end)
    else
      nil
    end
  end

  @doc """
  Get the current market data.
  """
  def get_data do
    if Process.whereis(__MODULE__) do
      Agent.get(__MODULE__, fn context ->
        Map.get(context, :data, %{})
      end)
    else
      %{}
    end
  end

  @doc """
  Get the current equity.
  """
  def get_equity do
    if Process.whereis(__MODULE__) do
      Agent.get(__MODULE__, fn context ->
        Map.get(context, :equity, 0.0)
      end)
    else
      0.0
    end
  end

  @doc """
  Get the current position state.
  """
  def get_position do
    if Process.whereis(__MODULE__) do
      Agent.get(__MODULE__, fn context ->
        Map.get(context, :position, :none)
      end)
    else
      :none
    end
  end

  @doc """
  Clear any set action.
  """
  def clear_action do
    if Process.whereis(__MODULE__) do
      Agent.update(__MODULE__, fn context ->
        Map.put(context, :action, nil)
      end)
    end
  end

  # Private helper functions

  defp calculate_equity(result) do
    result.starting_balance + result.total_profit_and_loss
  end

  defp determine_position(result) do
    if result.is_position_open do
      # Look at the last data point to determine if it's long or short
      case result.data_points do
        [%{action: :buy} | _] -> :long
        [%{action: :sell} | _] -> :short
        _ -> :none
      end
    else
      :none
    end
  end
end
