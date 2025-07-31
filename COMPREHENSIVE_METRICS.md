# Comprehensive Statistics and Metrics

This document describes the comprehensive statistics and metrics now available in ExPostFacto, bringing the library's analytics capabilities to professional trading standards.

## Overview

ExPostFacto now calculates over 30 different metrics that provide deep insights into trading strategy performance. These metrics are automatically calculated when you run `Result.compile/1` and can be accessed through the `Result.comprehensive_summary/1` function.

## Comprehensive Metrics Categories

### 1. Basic Performance Metrics

**Purpose**: Core profitability and duration metrics

- `total_return_pct`: Total percentage return of the strategy
- `cagr_pct`: Compound Annual Growth Rate
- `duration_days`: Number of days the backtest ran
- `trades_count`: Total number of completed trades

**Example Values**:

```elixir
%{
  total_return_pct: 25.42,
  cagr_pct: 16.80,
  duration_days: 365,
  trades_count: 93
}
```

### 2. Risk-Adjusted Performance Metrics

**Purpose**: Measure return quality relative to risk taken

#### Sharpe Ratio

- **Formula**: (Annual Return - Risk Free Rate) / Annual Volatility
- **Interpretation**:
  - > 1.0: Excellent risk-adjusted returns
  - 0.5-1.0: Good performance
  - < 0.5: Poor risk-adjusted returns

#### Sortino Ratio

- **Formula**: (Annual Return - Risk Free Rate) / Downside Volatility
- **Advantage**: Only considers downside volatility (negative returns)
- **Interpretation**: Higher values indicate better downside risk management

#### Calmar Ratio

- **Formula**: Annual Return / |Maximum Drawdown|
- **Interpretation**: Measures return relative to worst drawdown
- **Good Value**: > 0.5

**Example Values**:

```elixir
%{
  sharpe_ratio: 0.66,
  sortino_ratio: 1.30,
  calmar_ratio: 0.77,
  annual_volatility: 38.43
}
```

### 3. Drawdown Analysis

**Purpose**: Understand the magnitude and duration of losses

- `max_drawdown_pct`: Largest peak-to-trough decline
- `max_drawdown_duration_days`: Longest time to recover from a drawdown
- `average_drawdown_pct`: Average size of all drawdowns
- `average_drawdown_duration_days`: Average time to recover

**Example Values**:

```elixir
%{
  max_drawdown_pct: -33.08,
  max_drawdown_duration_days: 688,
  average_drawdown_pct: -5.58,
  average_drawdown_duration_days: 41
}
```

### 4. Trading Performance Metrics

**Purpose**: Analyze the effectiveness of individual trades

#### Profit Factor

- **Formula**: Gross Profit / |Gross Loss|
- **Interpretation**:
  - > 2.0: Excellent strategy
  - 1.5-2.0: Good strategy
  - 1.0-1.5: Marginal strategy
  - < 1.0: Losing strategy

#### Expectancy

- **Formula**: Total P&L / Number of Trades
- **Purpose**: Average expected profit per trade

#### Win Rate

- **Formula**: Winning Trades / Total Trades \* 100
- **Note**: High win rate doesn't guarantee profitability

**Example Values**:

```elixir
%{
  profit_factor: 2.13,
  expectancy: 691.50,
  expectancy_pct: 6.91,
  win_rate: 53.76,
  win_count: 50
}
```

### 5. Trade Analysis

**Purpose**: Detailed breakdown of trade characteristics

- `best_trade_pct`: Largest winning trade as percentage
- `worst_trade_pct`: Largest losing trade as percentage
- `average_trade_pct`: Average trade return as percentage
- `max_trade_duration_days`: Longest held position
- `average_trade_duration_days`: Average holding period

**Example Values**:

```elixir
%{
  best_trade_pct: 57.12,
  worst_trade_pct: -16.63,
  average_trade_pct: 1.96,
  max_trade_duration_days: 121,
  average_trade_duration_days: 32
}
```

### 6. Profit/Loss Breakdown

**Purpose**: Understand the composition of returns

- `gross_profit`: Total profits from winning trades
- `gross_loss`: Total losses from losing trades
- `average_winning_trade`: Average profit per winning trade
- `average_losing_trade`: Average loss per losing trade
- `largest_winning_trade`: Single largest profit
- `largest_losing_trade`: Single largest loss

### 7. System Quality Number (SQN)

**Purpose**: Measure the quality and reliability of the trading system

**Formula**: (Average Trade Result / Standard Deviation) \* √(Number of Trades)

**Interpretation**:

- < 1.6: Poor system
- 1.6-1.9: Below average but tradeable
- 2.0-2.4: Average system
- 2.5-2.9: Good system
- 3.0-5.0: Excellent system
- 5.0-6.9: Superb system
- > 7.0: Too good to be true (likely over-fitted)

**Example**:

```elixir
%{
  sqn: 1.78,
  sqn_interpretation: "Below average but tradeable"
}
```

### 8. Kelly Criterion

**Purpose**: Optimal position sizing for maximum long-term growth

**Formula**: (bp - q) / b
Where:

- b = odds ratio (average win / average loss)
- p = probability of winning
- q = probability of losing

**Interpretation**:

- Negative: No edge, avoid strategy
- 0-10%: Weak edge, small positions
- 10-25%: Moderate edge, reasonable strategy
- 25-40%: Strong edge, good strategy
- > 40%: Very strong edge, potentially too aggressive

**Example**:

```elixir
%{
  kelly_criterion: 0.6134,  # 61.34% - very aggressive!
  kelly_interpretation: "Very strong edge - potentially too aggressive"
}
```

### 9. Market Risk Analysis

**Purpose**: Compare strategy performance to market benchmarks

#### Alpha

- **Definition**: Excess return over what would be expected given market performance
- **Positive Alpha**: Strategy outperformed the market
- **Negative Alpha**: Strategy underperformed the market

#### Beta

- **Definition**: Sensitivity to market movements
- **Beta = 1.0**: Same volatility as market
- **Beta > 1.0**: More volatile than market
- **Beta < 1.0**: Less volatile than market

#### Information Ratio

- **Formula**: Alpha / Tracking Error
- **Purpose**: Risk-adjusted measure of active return

**Example Values**:

```elixir
%{
  alpha: 6.8,           # 6.8% excess return vs market
  beta: 0.85,           # 15% less volatile than market
  information_ratio: 0.45,
  tracking_error: 15.2,
  market_correlation: 0.65
}
```

## Usage Examples

### Getting Comprehensive Statistics

```elixir
# Run backtest
{:ok, output} = ExPostFacto.backtest(data, strategy, starting_balance: 100_000)

# Get comprehensive summary (clean map without internal data)
summary = ExPostFacto.Result.comprehensive_summary(output.result)

# Access specific metrics
IO.puts("Sharpe Ratio: #{summary.sharpe_ratio}")
IO.puts("Kelly Criterion: #{summary.kelly_criterion * 100}%")
IO.puts("SQN Rating: #{summary.sqn_interpretation}")
```

### Raw Result Access

```elixir
# Access raw result struct with all calculated fields
result = output.result

# All comprehensive metrics are available as struct fields
result.total_return_pct
result.sharpe_ratio
result.profit_factor
result.sqn
result.kelly_criterion
# ... and many more
```

### Professional Reporting

```elixir
def generate_report(summary) do
  """
  STRATEGY PERFORMANCE REPORT
  ===========================

  Returns:
  - Total Return: #{summary.total_return_pct}%
  - CAGR: #{summary.cagr_pct}%
  - Sharpe Ratio: #{summary.sharpe_ratio}

  Risk:
  - Max Drawdown: #{summary.max_drawdown_pct}%
  - Volatility: #{summary.annual_volatility}%

  Quality:
  - SQN: #{summary.sqn} (#{summary.sqn_interpretation})
  - Profit Factor: #{summary.profit_factor}

  Position Sizing:
  - Kelly %: #{summary.kelly_criterion * 100}%
  - Recommendation: #{summary.kelly_interpretation}
  """
end
```

## Implementation Notes

### Benchmark Assumptions

- Default risk-free rate: 2% annually
- Default market return: 10% annually (S&P 500 historical average)
- Market volatility estimate: 18% annually

These can be customized by calling the underlying calculation functions directly:

```elixir
alias ExPostFacto.TradeStats.{FinancialRatios, MarketRisk}

# Custom risk-free rate
sharpe = FinancialRatios.sharpe_ratio(result, 0.03)  # 3% risk-free rate

# Custom benchmark
alpha = MarketRisk.alpha(result, 12.0, 0.025)  # 12% benchmark, 2.5% risk-free
```

### Calculation Accuracy

- All metrics handle edge cases (zero trades, zero volatility, etc.)
- Time-series calculations are approximated when high-frequency data isn't available
- For maximum accuracy with Alpha/Beta, provide actual benchmark time series data

### Performance Impact

- All comprehensive statistics are calculated once during `Result.compile/1`
- No significant performance impact on backtesting speed
- Use `comprehensive_summary/1` for clean reporting without internal data structures

## Professional Standards

These metrics bring ExPostFacto to the same analytical standards as:

- Professional trading platforms (MetaTrader, TradeStation)
- Institutional risk management systems
- Academic finance research
- Hedge fund reporting standards

The implementation follows established formulas from:

- "Quantitative Trading" by Ernest Chan
- "Evidence-Based Technical Analysis" by David Aronson
- CFA Institute standards
- Academic finance literature

This comprehensive suite of metrics enables thorough strategy evaluation, risk assessment, and performance attribution analysis at a professional level.
