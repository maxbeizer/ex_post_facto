# Advanced ExPostFacto Tutorial: Building Professional Trading Strategies

This tutorial covers advanced topics for building robust, professional-grade trading strategies with ExPostFacto.

## Table of Contents

1. [Advanced Strategy Patterns](#advanced-strategy-patterns)
2. [Risk Management Framework](#risk-management-framework)
3. [Multi-Indicator Strategies](#multi-indicator-strategies)
4. [Portfolio Management](#portfolio-management)
5. [Performance Optimization](#performance-optimization)
6. [Statistical Validation](#statistical-validation)
7. [Production Deployment](#production-deployment)

## Advanced Strategy Patterns

### State Management Best Practices

Complex strategies require careful state management. Here's a robust pattern:

```elixir
defmodule AdvancedStrategy do
  use ExPostFacto.Strategy
  
  defstruct [
    # Configuration
    :config,
    
    # Market data tracking
    :price_history,
    :volume_history,
    
    # Indicator states
    :indicators,
    
    # Position tracking
    :current_position,
    :entry_price,
    :entry_time,
    
    # Risk management
    :stop_loss,
    :take_profit,
    :trailing_stop,
    
    # Performance tracking
    :trades_today,
    :daily_pnl
  ]
  
  def init(opts) do
    config = build_config(opts)
    
    state = %__MODULE__{
      config: config,
      price_history: [],
      volume_history: [],
      indicators: %{},
      current_position: :none,
      trades_today: 0,
      daily_pnl: 0.0
    }
    
    {:ok, state}
  end
  
  def next(state) do
    # Update market data
    state = update_market_data(state)
    
    # Calculate indicators
    state = update_indicators(state)
    
    # Risk management checks
    state = check_risk_limits(state)
    
    # Trading logic
    state = execute_trading_logic(state)
    
    {:ok, state}
  end
  
  defp build_config(opts) do
    %{
      max_position_size: Keyword.get(opts, :max_position_size, 0.1),
      max_daily_trades: Keyword.get(opts, :max_daily_trades, 5),
      max_daily_loss: Keyword.get(opts, :max_daily_loss, 0.02),
      stop_loss_pct: Keyword.get(opts, :stop_loss_pct, 0.02),
      take_profit_pct: Keyword.get(opts, :take_profit_pct, 0.04)
    }
  end
end
```

### Dynamic Parameter Adjustment

Adapt strategy parameters based on market conditions:

```elixir
defmodule AdaptiveStrategy do
  use ExPostFacto.Strategy
  
  def init(opts) do
    {:ok, %{
      base_rsi_period: Keyword.get(opts, :rsi_period, 14),
      current_rsi_period: 14,
      volatility_history: [],
      market_regime: :normal  # :trending, :ranging, :volatile
    }}
  end
  
  def next(state) do
    # Calculate market volatility
    state = update_volatility(state)
    
    # Detect market regime
    state = detect_market_regime(state)
    
    # Adjust parameters based on regime
    state = adjust_parameters(state)
    
    # Execute strategy with adapted parameters
    execute_strategy(state)
  end
  
  defp detect_market_regime(state) do
    if length(state.volatility_history) >= 20 do
      recent_volatility = Enum.take(state.volatility_history, 20) |> Enum.sum() / 20
      
      regime = cond do
        recent_volatility > 0.03 -> :volatile
        recent_volatility < 0.01 -> :ranging
        true -> :trending
      end
      
      %{state | market_regime: regime}
    else
      state
    end
  end
  
  defp adjust_parameters(state) do
    rsi_period = case state.market_regime do
      :volatile -> state.base_rsi_period + 7  # Longer period for stability
      :ranging -> state.base_rsi_period - 3   # Shorter for responsiveness
      :trending -> state.base_rsi_period      # Standard period
    end
    
    %{state | current_rsi_period: rsi_period}
  end
end
```

## Risk Management Framework

### Position Sizing with Kelly Criterion

Implement dynamic position sizing based on historical performance:

```elixir
defmodule KellyPositionSizing do
  @moduledoc """
  Calculate optimal position size using Kelly Criterion.
  """
  
  def calculate_position_size(trade_history, win_rate, avg_win, avg_loss, max_size \\ 0.25) do
    if length(trade_history) >= 20 do  # Minimum trades for statistical significance
      # Kelly formula: f = (bp - q) / b
      # where b = avg_win/avg_loss, p = win_rate, q = 1 - win_rate
      
      b = avg_win / abs(avg_loss)
      p = win_rate / 100.0
      q = 1.0 - p
      
      kelly_fraction = (b * p - q) / b
      
      # Apply safety margin and cap
      safe_fraction = kelly_fraction * 0.5  # 50% of Kelly for safety
      min(safe_fraction, max_size)
    else
      0.05  # Conservative default for insufficient data
    end
  end
end

defmodule RiskManagedStrategy do
  use ExPostFacto.Strategy
  
  def init(opts) do
    {:ok, %{
      trade_history: [],
      win_count: 0,
      total_trades: 0,
      total_wins: 0.0,
      total_losses: 0.0,
      position_size: 0.05
    }}
  end
  
  def next(state) do
    # Update position sizing based on performance
    state = update_position_sizing(state)
    
    # Your trading logic here...
    if should_buy?(state) do
      # Use calculated position size
      buy()  # In real implementation, you'd specify size
    end
    
    {:ok, state}
  end
  
  defp update_position_sizing(state) do
    if state.total_trades >= 20 do
      win_rate = (state.win_count / state.total_trades) * 100
      avg_win = state.total_wins / max(state.win_count, 1)
      avg_loss = state.total_losses / max(state.total_trades - state.win_count, 1)
      
      new_size = KellyPositionSizing.calculate_position_size(
        state.trade_history,
        win_rate,
        avg_win,
        avg_loss
      )
      
      %{state | position_size: new_size}
    else
      state
    end
  end
end
```

### Advanced Stop Loss Strategies

Implement multiple stop loss types:

```elixir
defmodule AdvancedStopLoss do
  defstruct [
    :type,           # :fixed, :trailing, :atr, :volatility
    :value,          # Stop loss value/percentage
    :initial_price,  # Entry price
    :highest_price,  # For trailing stops
    :atr_multiplier  # For ATR-based stops
  ]
  
  def new(type, opts \\ []) do
    %__MODULE__{
      type: type,
      value: Keyword.get(opts, :value, 0.02),
      atr_multiplier: Keyword.get(opts, :atr_multiplier, 2.0)
    }
  end
  
  def update(%__MODULE__{type: :trailing} = stop, current_price, position_type) do
    case position_type do
      :long ->
        new_highest = max(stop.highest_price || current_price, current_price)
        new_stop_price = new_highest * (1 - stop.value)
        %{stop | highest_price: new_highest, value: new_stop_price}
        
      :short ->
        new_lowest = min(stop.highest_price || current_price, current_price)
        new_stop_price = new_lowest * (1 + stop.value)
        %{stop | highest_price: new_lowest, value: new_stop_price}
    end
  end
  
  def triggered?(%__MODULE__{} = stop, current_price, position_type) do
    case {stop.type, position_type} do
      {:fixed, :long} -> current_price <= stop.initial_price * (1 - stop.value)
      {:fixed, :short} -> current_price >= stop.initial_price * (1 + stop.value)
      {:trailing, :long} -> current_price <= stop.value
      {:trailing, :short} -> current_price >= stop.value
    end
  end
end
```

## Multi-Indicator Strategies

### Signal Aggregation Framework

Build a system to combine multiple indicators effectively:

```elixir
defmodule SignalAggregator do
  defstruct [:signals, :weights, :threshold]
  
  def new(threshold \\ 0.6) do
    %__MODULE__{
      signals: %{},
      weights: %{},
      threshold: threshold
    }
  end
  
  def add_signal(aggregator, name, value, weight \\ 1.0) do
    signals = Map.put(aggregator.signals, name, value)
    weights = Map.put(aggregator.weights, name, weight)
    %{aggregator | signals: signals, weights: weights}
  end
  
  def get_consensus(aggregator) do
    if map_size(aggregator.signals) == 0 do
      :neutral
    else
      total_weight = aggregator.weights |> Map.values() |> Enum.sum()
      
      weighted_sum = 
        Enum.reduce(aggregator.signals, 0, fn {name, signal}, acc ->
          weight = Map.get(aggregator.weights, name, 1.0)
          signal_value = case signal do
            :buy -> 1.0
            :sell -> -1.0
            :neutral -> 0.0
            _ -> 0.0
          end
          acc + (signal_value * weight)
        end)
      
      consensus_score = weighted_sum / total_weight
      
      cond do
        consensus_score >= aggregator.threshold -> :buy
        consensus_score <= -aggregator.threshold -> :sell
        true -> :neutral
      end
    end
  end
end

defmodule MultiIndicatorStrategy do
  use ExPostFacto.Strategy
  
  def init(opts) do
    {:ok, %{
      rsi_period: Keyword.get(opts, :rsi_period, 14),
      macd_params: Keyword.get(opts, :macd_params, {12, 26, 9}),
      bb_params: Keyword.get(opts, :bb_params, {20, 2.0}),
      price_history: [],
      signal_aggregator: SignalAggregator.new(0.7)
    }}
  end
  
  def next(state) do
    current_price = data().close
    price_history = [current_price | state.price_history]
    
    if length(price_history) >= 30 do
      # Calculate individual signals
      rsi_signal = get_rsi_signal(price_history, state.rsi_period)
      macd_signal = get_macd_signal(price_history, state.macd_params)
      bb_signal = get_bb_signal(current_price, price_history, state.bb_params)
      
      # Aggregate signals with different weights
      aggregator = 
        SignalAggregator.new(0.7)
        |> SignalAggregator.add_signal(:rsi, rsi_signal, 1.0)
        |> SignalAggregator.add_signal(:macd, macd_signal, 1.5)  # Higher weight
        |> SignalAggregator.add_signal(:bb, bb_signal, 1.0)
      
      consensus = SignalAggregator.get_consensus(aggregator)
      
      # Execute trades based on consensus
      case {consensus, position()} do
        {:buy, pos} when pos != :long ->
          if pos == :short, do: close_sell()
          buy()
        {:sell, pos} when pos != :short ->
          if pos == :long, do: close_buy()
          sell()
        _ -> :ok
      end
    end
    
    {:ok, %{state | price_history: price_history}}
  end
  
  defp get_rsi_signal(prices, period) do
    rsi_values = indicator(:rsi, prices, period)
    current_rsi = List.first(rsi_values)
    
    cond do
      current_rsi < 30 -> :buy
      current_rsi > 70 -> :sell
      true -> :neutral
    end
  end
  
  defp get_macd_signal(prices, {fast, slow, signal}) do
    {macd_line, signal_line, _} = indicator(:macd, prices, {fast, slow, signal})
    
    if List.first(macd_line) > List.first(signal_line) do
      :buy
    else
      :sell
    end
  end
  
  defp get_bb_signal(current_price, prices, {period, std_dev}) do
    {upper, _middle, lower} = indicator(:bollinger_bands, prices, {period, std_dev})
    
    cond do
      current_price <= lower -> :buy
      current_price >= upper -> :sell
      true -> :neutral
    end
  end
end
```

## Performance Optimization

### Concurrent Indicator Calculation

For strategies using many indicators, calculate them concurrently:

```elixir
defmodule ConcurrentIndicators do
  def calculate_all(price_history, indicator_configs) do
    tasks = Enum.map(indicator_configs, fn {name, type, params} ->
      Task.async(fn ->
        result = ExPostFacto.Indicators.apply(type, [price_history | params])
        {name, result}
      end)
    end)
    
    tasks
    |> Task.await_many(5000)  # 5 second timeout
    |> Enum.into(%{})
  end
end

defmodule HighPerformanceStrategy do
  use ExPostFacto.Strategy
  
  def next(state) do
    price_history = [data().close | state.price_history]
    
    if length(price_history) >= 50 do
      # Calculate multiple indicators concurrently
      indicator_configs = [
        {:rsi, :rsi, [14]},
        {:macd, :macd, [{12, 26, 9}]},
        {:bb, :bollinger_bands, [{20, 2.0}]},
        {:sma_fast, :sma, [10]},
        {:sma_slow, :sma, [20]}
      ]
      
      indicators = ConcurrentIndicators.calculate_all(price_history, indicator_configs)
      
      # Use calculated indicators for trading decisions
      make_trading_decision(indicators, state)
    end
    
    {:ok, %{state | price_history: price_history}}
  end
end
```

### Memory-Efficient History Management

Manage memory usage for long-running strategies:

```elixir
defmodule MemoryEfficientStrategy do
  use ExPostFacto.Strategy
  
  def init(opts) do
    max_history = Keyword.get(opts, :max_history, 200)
    {:ok, %{
      max_history: max_history,
      price_history: [],
      indicator_cache: %{}
    }}
  end
  
  def next(state) do
    # Add new price and trim history
    new_history = 
      [data().close | state.price_history]
      |> Enum.take(state.max_history)
    
    # Cache expensive calculations
    state = update_indicator_cache(new_history, state)
    
    {:ok, %{state | price_history: new_history}}
  end
  
  defp update_indicator_cache(prices, state) do
    # Only recalculate if we have new data
    cache_key = :erlang.phash2(Enum.take(prices, 10))
    
    if Map.get(state.indicator_cache, cache_key) do
      state
    else
      # Calculate and cache
      new_indicators = %{
        rsi: indicator(:rsi, prices, 14) |> List.first(),
        sma: indicator(:sma, prices, 20) |> List.first()
      }
      
      # Keep only recent cache entries
      trimmed_cache = 
        state.indicator_cache
        |> Enum.take(10)  # Keep last 10 entries
        |> Enum.into(%{})
        |> Map.put(cache_key, new_indicators)
      
      %{state | indicator_cache: trimmed_cache}
    end
  end
end
```

## Statistical Validation

### Walk-Forward Analysis

Implement robust strategy validation:

```elixir
defmodule StrategyValidator do
  def walk_forward_analysis(data, strategy_module, param_ranges, opts \\ []) do
    training_window = Keyword.get(opts, :training_window, 252)  # 1 year
    test_window = Keyword.get(opts, :test_window, 63)           # 3 months
    step_size = Keyword.get(opts, :step_size, 21)              # 1 month
    
    total_length = length(data)
    window_size = training_window + test_window
    
    if total_length < window_size do
      {:error, "Insufficient data for walk-forward analysis"}
    else
      results = 
        0..div(total_length - window_size, step_size)
        |> Enum.map(fn step ->
          start_idx = step * step_size
          
          training_data = Enum.slice(data, start_idx, training_window)
          test_data = Enum.slice(data, start_idx + training_window, test_window)
          
          # Optimize on training data
          {:ok, optimization} = ExPostFacto.optimize(
            training_data,
            strategy_module,
            param_ranges,
            maximize: :sharpe_ratio
          )
          
          # Test on out-of-sample data
          {:ok, test_result} = ExPostFacto.backtest(
            test_data,
            {strategy_module, optimization.best_params}
          )
          
          %{
            step: step,
            training_period: {start_idx, start_idx + training_window},
            test_period: {start_idx + training_window, start_idx + training_window + test_window},
            best_params: optimization.best_params,
            training_sharpe: optimization.best_score,
            test_sharpe: test_result.result.sharpe_ratio || 0.0,
            test_return: test_result.result.total_return_percentage
          }
        end)
      
      {:ok, analyze_walk_forward_results(results)}
    end
  end
  
  defp analyze_walk_forward_results(results) do
    test_returns = Enum.map(results, & &1.test_return)
    test_sharpes = Enum.map(results, & &1.test_sharpe)
    
    %{
      periods: length(results),
      avg_test_return: Enum.sum(test_returns) / length(test_returns),
      avg_test_sharpe: Enum.sum(test_sharpes) / length(test_sharpes),
      consistency: calculate_consistency(test_returns),
      parameter_stability: analyze_parameter_stability(results),
      detailed_results: results
    }
  end
  
  defp calculate_consistency(returns) do
    positive_periods = Enum.count(returns, &(&1 > 0))
    positive_periods / length(returns)
  end
  
  defp analyze_parameter_stability(results) do
    # Analyze how much parameters change between periods
    param_changes = 
      results
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [prev, curr] ->
        calculate_param_difference(prev.best_params, curr.best_params)
      end)
    
    Enum.sum(param_changes) / length(param_changes)
  end
  
  defp calculate_param_difference(params1, params2) do
    # Simple difference calculation - you might want to normalize this
    common_keys = MapSet.intersection(MapSet.new(Map.keys(params1)), MapSet.new(Map.keys(params2)))
    
    Enum.reduce(common_keys, 0, fn key, acc ->
      diff = abs(params1[key] - params2[key])
      acc + diff
    end) / MapSet.size(common_keys)
  end
end
```

### Monte Carlo Analysis

Test strategy robustness with randomized scenarios:

```elixir
defmodule MonteCarloAnalysis do
  def bootstrap_analysis(trade_results, iterations \\ 1000) do
    original_return = Enum.sum(trade_results)
    
    bootstrap_returns = 
      1..iterations
      |> Enum.map(fn _ ->
        # Resample trades with replacement
        resampled_trades = 
          1..length(trade_results)
          |> Enum.map(fn _ -> Enum.random(trade_results) end)
        
        Enum.sum(resampled_trades)
      end)
      |> Enum.sort()
    
    # Calculate confidence intervals
    lower_5pct = Enum.at(bootstrap_returns, round(iterations * 0.05))
    upper_95pct = Enum.at(bootstrap_returns, round(iterations * 0.95))
    
    %{
      original_return: original_return,
      bootstrap_mean: Enum.sum(bootstrap_returns) / iterations,
      confidence_interval_95: {lower_5pct, upper_95pct},
      probability_positive: Enum.count(bootstrap_returns, &(&1 > 0)) / iterations,
      worst_case_5pct: lower_5pct,
      best_case_5pct: upper_95pct
    }
  end
end
```

## Production Deployment

### Strategy Monitoring

Implement comprehensive monitoring for live strategies:

```elixir
defmodule StrategyMonitor do
  use GenServer
  
  defstruct [
    :strategy_name,
    :performance_metrics,
    :alert_thresholds,
    :trade_log
  ]
  
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def init(opts) do
    state = %__MODULE__{
      strategy_name: Keyword.get(opts, :name, "Unknown"),
      performance_metrics: %{},
      alert_thresholds: Keyword.get(opts, :thresholds, default_thresholds()),
      trade_log: []
    }
    
    # Schedule periodic health checks
    :timer.send_interval(60_000, self(), :health_check)
    
    {:ok, state}
  end
  
  def handle_info(:health_check, state) do
    # Check performance metrics against thresholds
    alerts = check_alert_conditions(state)
    
    if length(alerts) > 0 do
      send_alerts(alerts, state.strategy_name)
    end
    
    {:noreply, state}
  end
  
  defp default_thresholds do
    %{
      max_drawdown: 0.10,
      min_sharpe: 0.5,
      max_consecutive_losses: 5,
      max_daily_loss: 0.05
    }
  end
  
  defp check_alert_conditions(state) do
    # Implement your alert logic here
    []
  end
  
  defp send_alerts(alerts, strategy_name) do
    # Send notifications (email, Slack, etc.)
    Enum.each(alerts, fn alert ->
      Logger.warning("Strategy Alert [#{strategy_name}]: #{alert}")
    end)
  end
end
```

### Performance Benchmarking

Compare your strategy against benchmarks:

```elixir
defmodule BenchmarkComparison do
  def compare_to_buy_hold(strategy_result, market_data) do
    # Calculate buy-and-hold return
    first_price = List.first(market_data).close
    last_price = List.last(market_data).close
    buy_hold_return = (last_price - first_price) / first_price * 100
    
    strategy_return = strategy_result.result.total_return_percentage
    
    %{
      strategy_return: strategy_return,
      buy_hold_return: buy_hold_return,
      excess_return: strategy_return - buy_hold_return,
      strategy_sharpe: strategy_result.result.sharpe_ratio,
      outperformed: strategy_return > buy_hold_return
    }
  end
  
  def risk_adjusted_comparison(strategy_result, benchmark_result) do
    %{
      strategy_sharpe: strategy_result.result.sharpe_ratio,
      benchmark_sharpe: benchmark_result.sharpe_ratio,
      strategy_max_dd: strategy_result.result.max_draw_down_percentage,
      benchmark_max_dd: benchmark_result.max_draw_down_percentage,
      risk_adjusted_winner: determine_winner(strategy_result, benchmark_result)
    }
  end
  
  defp determine_winner(strategy, benchmark) do
    # Simple scoring system - you might want something more sophisticated
    strategy_score = 
      (strategy.result.sharpe_ratio || 0) - 
      (strategy.result.max_draw_down_percentage / 10)
    
    benchmark_score = 
      (benchmark.sharpe_ratio || 0) - 
      (benchmark.max_draw_down_percentage / 10)
    
    if strategy_score > benchmark_score, do: :strategy, else: :benchmark
  end
end
```

## Conclusion

This advanced tutorial covers the essential patterns for building professional trading strategies with ExPostFacto. Key takeaways:

1. **Structure Matters**: Use proper state management and modular design
2. **Risk First**: Always implement comprehensive risk management
3. **Validate Thoroughly**: Use walk-forward analysis and statistical validation
4. **Monitor Continuously**: Implement proper monitoring and alerting
5. **Benchmark Everything**: Compare your strategies against relevant benchmarks

The patterns shown here form the foundation for building robust, production-ready trading systems. Adapt them to your specific needs and always test thoroughly before deploying capital.

## Next Steps

- Implement your own risk management framework
- Build a portfolio allocation system
- Add machine learning components for adaptive strategies
- Integrate with live data feeds and execution systems
- Develop a comprehensive backtesting pipeline

Happy trading! 🚀