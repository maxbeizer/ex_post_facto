# Parameter Optimization Framework

ExPostFacto now includes a comprehensive parameter optimization framework that enables systematic strategy development and parameter tuning.

## Features

### 1. Grid Search Optimization
Systematically tests all combinations of parameter values within specified ranges.

```elixir
{:ok, results} = ExPostFacto.optimize(
  market_data,
  MyStrategy,
  [fast: 5..20, slow: 20..50],
  maximize: :sharpe_ratio
)
```

### 2. Random Search Optimization
Randomly samples parameter combinations for efficient exploration of large parameter spaces.

```elixir
{:ok, results} = ExPostFacto.optimize(
  market_data,
  MyStrategy,
  [fast: 5..20, slow: 20..50],
  method: :random_search,
  samples: 100,
  maximize: :total_return_pct
)
```

### 3. Walk-Forward Analysis
Tests parameter robustness over time using rolling training and validation windows.

```elixir
{:ok, results} = ExPostFacto.optimize(
  market_data,
  MyStrategy,
  [fast: 5..15, slow: 20..40],
  method: :walk_forward,
  training_window: 100,
  validation_window: 50,
  step_size: 25
)
```

### 4. Parameter Heatmaps
Generates visualization data for analyzing 2D parameter relationships.

```elixir
{:ok, heatmap} = ExPostFacto.heatmap(results, :fast, :slow)

# Access heatmap data
x_values = heatmap.x_values     # [5, 6, 7, ...]
y_values = heatmap.y_values     # [20, 21, 22, ...]
scores = heatmap.scores         # [[0.1, 0.2, ...], [0.3, 0.4, ...]]
```

## Supported Optimization Metrics

- `:sharpe_ratio` - Risk-adjusted return (Sharpe ratio)
- `:total_return_pct` - Total percentage return
- `:cagr_pct` - Compound Annual Growth Rate
- `:profit_factor` - Gross profit / gross loss ratio
- `:sqn` - System Quality Number
- `:win_rate` - Percentage of winning trades
- `:max_draw_down_percentage` - Maximum drawdown (minimized)

## Parameter Specification

Parameters can be specified as:
- **Ranges**: `fast_period: 5..20`
- **Lists**: `fast_period: [5, 10, 15, 20]`
- **Single values**: `fast_period: 10`

## Result Structure

Optimization results include:

```elixir
%{
  best_params: [fast_period: 12, slow_period: 26],
  best_score: 1.42,
  best_output: %ExPostFacto.Output{...},
  all_results: [...],
  method: :grid_search,
  metric: :sharpe_ratio
}
```

## Walk-Forward Analysis Results

Walk-forward analysis provides additional insights:

```elixir
%{
  windows: [...],                    # Results for each window
  summary: %{                       # Aggregated metrics
    total_windows: 10,
    valid_windows: 8,
    average_validation_score: 0.85
  },
  parameters_stability: %{          # Parameter stability analysis
    parameter_stability: %{
      fast_period: %{
        unique_values: 3,
        stability_ratio: 0.375,
        most_common: 12
      }
    },
    overall_stability: 0.42
  }
}
```

## Error Handling

The framework includes comprehensive error handling:
- Invalid parameter ranges
- Insufficient data for walk-forward analysis
- Strategy initialization failures
- Missing optimization metrics

## Performance Considerations

- Grid search: Limited by `max_combinations` (default: 1000)
- Random search: Efficient for large parameter spaces
- Walk-forward: Requires sufficient data length
- All methods leverage existing backtesting infrastructure

## Integration

The optimization framework integrates seamlessly with:
- Strategy behaviour modules
- Traditional MFA tuple strategies
- All existing ExPostFacto features
- Comprehensive metrics and statistics

This professional-grade optimization framework enables systematic strategy development and robust parameter tuning for quantitative trading strategies.