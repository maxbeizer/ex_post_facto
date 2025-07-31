defmodule ExPostFacto.ExampleStrategies.PortfolioRebalancingStrategy do
  @moduledoc """
  Portfolio rebalancing strategy for multiple assets.

  This strategy demonstrates portfolio management concepts by rebalancing
  between different assets based on their relative performance and target allocations.
  While ExPostFacto primarily handles single-asset backtesting, this example shows
  how to simulate portfolio concepts within the framework.

  ## Concept

  The strategy simulates a portfolio by:
  - Treating the main asset as a proxy for portfolio performance
  - Using momentum and mean reversion signals to simulate rebalancing decisions
  - Implementing position sizing based on volatility and correlation proxies

  ## Strategy Logic

  - Calculate rolling volatility and momentum for risk adjustment
  - Use RSI and moving averages to simulate multi-asset momentum
  - Implement volatility-based position sizing
  - Rebalance positions based on performance divergence

  ## Parameters

  - `:volatility_period` - Period for volatility calculation (default: 20)
  - `:momentum_period` - Period for momentum calculation (default: 12)
  - `:rebalance_threshold` - Threshold for triggering rebalancing (default: 0.05)
  - `:target_volatility` - Target portfolio volatility (default: 0.15)
  - `:max_position_size` - Maximum position size (default: 1.0)
  - `:min_position_size` - Minimum position size (default: 0.2)

  ## Example

      # Basic portfolio rebalancing
      {:ok, result} = ExPostFacto.backtest(
        market_data,
        {ExPostFacto.ExampleStrategies.PortfolioRebalancingStrategy, [
          volatility_period: 30,
          momentum_period: 10,
          target_volatility: 0.12
        ]}
      )
  """

  use ExPostFacto.Strategy

  def init(opts) do
    volatility_period = Keyword.get(opts, :volatility_period, 20)
    momentum_period = Keyword.get(opts, :momentum_period, 12)
    rebalance_threshold = Keyword.get(opts, :rebalance_threshold, 0.05)
    target_volatility = Keyword.get(opts, :target_volatility, 0.15)
    max_position_size = Keyword.get(opts, :max_position_size, 1.0)
    min_position_size = Keyword.get(opts, :min_position_size, 0.2)

    {:ok,
     %{
       # Configuration
       volatility_period: volatility_period,
       momentum_period: momentum_period,
       rebalance_threshold: rebalance_threshold,
       target_volatility: target_volatility,
       max_position_size: max_position_size,
       min_position_size: min_position_size,

       # State tracking
       price_history: [],
       return_history: [],
       volatility_history: [],
       momentum_history: [],

       # Portfolio state
       current_allocation: 0.5,
       target_allocation: 0.5,
       last_rebalance_price: nil,
       days_since_rebalance: 0
     }}
  end

  def next(state) do
    current_price = data().close
    updated_history = [current_price | state.price_history]

    # Calculate returns if we have previous price
    new_state =
      if length(updated_history) >= 2 do
        prev_price = Enum.at(updated_history, 1)
        daily_return = (current_price - prev_price) / prev_price

        updated_returns = [daily_return | state.return_history]

        state = %{
          state
          | price_history: updated_history,
            return_history: updated_returns,
            days_since_rebalance: state.days_since_rebalance + 1
        }

        # Update portfolio metrics if we have sufficient data
        if length(updated_returns) >= state.volatility_period do
          state = update_portfolio_metrics(state)
          state = calculate_target_allocation(state)
          execute_rebalancing_logic(state)
        else
          state
        end
      else
        %{state | price_history: updated_history}
      end

    {:ok, new_state}
  end

  # Private helper functions

  defp update_portfolio_metrics(state) do
    # Calculate rolling volatility
    recent_returns = Enum.take(state.return_history, state.volatility_period)
    current_volatility = calculate_volatility(recent_returns)

    # Calculate momentum
    momentum = calculate_momentum(state.price_history, state.momentum_period)

    # Update histories
    volatility_history = [current_volatility | state.volatility_history] |> Enum.take(50)
    momentum_history = [momentum | state.momentum_history] |> Enum.take(50)

    %{
      state
      | volatility_history: volatility_history,
        momentum_history: momentum_history
    }
  end

  defp calculate_volatility(returns) do
    if length(returns) < 2 do
      0.0
    else
      mean_return = Enum.sum(returns) / length(returns)

      variance =
        returns
        |> Enum.map(fn r -> :math.pow(r - mean_return, 2) end)
        |> Enum.sum()
        |> Kernel./(length(returns) - 1)

      :math.sqrt(variance) * :math.sqrt(252)  # Annualized volatility
    end
  end

  defp calculate_momentum(prices, period) do
    if length(prices) >= period do
      current_price = List.first(prices)
      past_price = Enum.at(prices, period - 1)
      (current_price - past_price) / past_price
    else
      0.0
    end
  end

  defp calculate_target_allocation(state) do
    if length(state.volatility_history) >= 5 and length(state.momentum_history) >= 5 do
      current_volatility = List.first(state.volatility_history)
      current_momentum = List.first(state.momentum_history)

      # Volatility-based adjustment
      volatility_adjustment = 
        if current_volatility > 0 do
          state.target_volatility / current_volatility
        else
          1.0
        end

      # Momentum-based adjustment
      momentum_adjustment = case current_momentum do
        m when m > 0.02 -> 1.2    # Strong positive momentum - increase allocation
        m when m < -0.02 -> 0.8   # Strong negative momentum - decrease allocation
        _ -> 1.0                  # Neutral momentum
      end

      # Calculate target allocation
      base_allocation = 0.5
      adjusted_allocation = base_allocation * volatility_adjustment * momentum_adjustment

      # Clamp to reasonable bounds
      target = 
        adjusted_allocation
        |> max(state.min_position_size)
        |> min(state.max_position_size)

      %{state | target_allocation: target}
    else
      state
    end
  end

  defp execute_rebalancing_logic(state) do
    allocation_difference = abs(state.target_allocation - state.current_allocation)
    current_position = position()

    # Check if rebalancing is needed
    should_rebalance = 
      allocation_difference > state.rebalance_threshold or
      state.days_since_rebalance > 21  # Force rebalance after 21 days

    if should_rebalance do
      # Determine new position based on target allocation
      new_position_type = cond do
        state.target_allocation > 0.7 -> :strong_long
        state.target_allocation > 0.3 -> :long
        state.target_allocation < 0.3 -> :short
        true -> :neutral
      end

      # Execute position changes
      execute_position_change(current_position, new_position_type, state)
    else
      state
    end
  end

  defp execute_position_change(current_position, target_position, state) do
    case {current_position, target_position} do
      {pos, pos} ->
        # No change needed
        state

      {_, :strong_long} ->
        # Close any short positions and go long
        if current_position == :short, do: close_sell()
        buy()
        update_rebalance_state(state, state.target_allocation)

      {_, :long} ->
        # Moderate long position
        if current_position == :short, do: close_sell()
        if current_position == :none, do: buy()
        update_rebalance_state(state, state.target_allocation)

      {_, :short} ->
        # Short position
        if current_position == :long, do: close_buy()
        sell()
        update_rebalance_state(state, state.target_allocation)

      {_, :neutral} ->
        # Close all positions
        case current_position do
          :long -> close_buy()
          :short -> close_sell()
          _ -> :ok
        end
        update_rebalance_state(state, 0.0)
    end
  end

  defp update_rebalance_state(state, new_allocation) do
    current_price = data().close

    %{
      state
      | current_allocation: new_allocation,
        last_rebalance_price: current_price,
        days_since_rebalance: 0
    }
  end
end