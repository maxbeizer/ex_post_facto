# Migration Guide: From Other Backtesting Libraries to ExPostFacto

This guide helps you migrate from popular backtesting libraries to ExPostFacto, highlighting the differences and providing code translation examples.

## Table of Contents

- [From Python backtesting.py](#from-python-backtestingpy)
- [From Backtrader](#from-backtrader)
- [From Zipline](#from-zipline)  
- [From QuantConnect](#from-quantconnect)
- [From Pine Script](#from-pine-script)
- [Feature Comparison](#feature-comparison)
- [Common Migration Patterns](#common-migration-patterns)

## From Python backtesting.py

### Basic Structure Comparison

**Python backtesting.py:**
```python
from backtesting import Backtest, Strategy
import pandas as pd

class SMAStrategy(Strategy):
    n1 = 10  # Fast SMA
    n2 = 20  # Slow SMA
    
    def init(self):
        self.sma1 = self.I(SMA, self.data.Close, self.n1)
        self.sma2 = self.I(SMA, self.data.Close, self.n2)
    
    def next(self):
        if crossover(self.sma1, self.sma2):
            self.buy()
        elif crossover(self.sma2, self.sma1):
            self.sell()

# Run backtest
data = pd.read_csv('data.csv', index_col=0, parse_dates=True)
bt = Backtest(data, SMAStrategy)
result = bt.run()
```

**ExPostFacto equivalent:**
```elixir
defmodule SMAStrategy do
  use ExPostFacto.Strategy
  
  def init(opts) do
    {:ok, %{
      n1: Keyword.get(opts, :n1, 10),
      n2: Keyword.get(opts, :n2, 20),
      price_history: [],
      sma1_history: [],
      sma2_history: []
    }}
  end
  
  def next(state) do
    current_price = data().close
    price_history = [current_price | state.price_history]
    
    sma1 = indicator(:sma, price_history, state.n1)
    sma2 = indicator(:sma, price_history, state.n2)
    
    sma1_history = [sma1 | state.sma1_history]
    sma2_history = [sma2 | state.sma2_history]
    
    # Check for crossovers
    if crossover?(sma1_history, sma2_history) do
      buy()
    elsif crossover?(sma2_history, sma1_history) do
      sell()
    end
    
    {:ok, %{state | 
      price_history: price_history,
      sma1_history: sma1_history,
      sma2_history: sma2_history
    }}
  end
end

# Run backtest
{:ok, result} = ExPostFacto.backtest(
  "data.csv",
  {SMAStrategy, [n1: 10, n2: 20]},
  starting_balance: 10_000.0
)
```

### Key Differences

| backtesting.py | ExPostFacto | Notes |
|----------------|-------------|-------|
| `self.I(indicator, ...)` | `indicator(:name, data, params)` | Built-in indicators |
| `self.buy()` | `buy()` | Position management |
| `self.sell()` | `sell()` | Position management |
| `crossover(a, b)` | `crossover?(a, b)` | Signal detection |
| `self.data.Close` | `data().close` | Data access |
| Parameters as class attributes | Parameters in `init/1` opts | Configuration |

### Optimization Comparison

**Python backtesting.py:**
```python
result = bt.optimize(
    n1=range(5, 20),
    n2=range(20, 50),
    maximize='Sharpe Ratio'
)
```

**ExPostFacto:**
```elixir
{:ok, result} = ExPostFacto.optimize(
  data,
  SMAStrategy,
  [n1: 5..19, n2: 20..49],
  maximize: :sharpe_ratio
)
```

## From Backtrader

### Strategy Translation

**Backtrader:**
```python
import backtrader as bt

class RSIStrategy(bt.Strategy):
    params = (
        ('rsi_period', 14),
        ('rsi_upper', 70),
        ('rsi_lower', 30),
    )
    
    def __init__(self):
        self.rsi = bt.indicators.RSI(period=self.params.rsi_period)
    
    def next(self):
        if not self.position:
            if self.rsi < self.params.rsi_lower:
                self.buy()
        else:
            if self.rsi > self.params.rsi_upper:
                self.sell()
```

**ExPostFacto:**
```elixir
defmodule RSIStrategy do
  use ExPostFacto.Strategy
  
  def init(opts) do
    {:ok, %{
      rsi_period: Keyword.get(opts, :rsi_period, 14),
      rsi_upper: Keyword.get(opts, :rsi_upper, 70),
      rsi_lower: Keyword.get(opts, :rsi_lower, 30),
      price_history: []
    }}
  end
  
  def next(state) do
    price_history = [data().close | state.price_history]
    rsi_values = indicator(:rsi, price_history, state.rsi_period)
    current_rsi = List.first(rsi_values)
    
    current_position = position()
    
    cond do
      current_position == :none and current_rsi < state.rsi_lower ->
        buy()
      current_position == :long and current_rsi > state.rsi_upper ->
        close_buy()
      true ->
        :ok
    end
    
    {:ok, %{state | price_history: price_history}}
  end
end
```

### Position Management

| Backtrader | ExPostFacto | Description |
|------------|-------------|-------------|
| `self.buy()` | `buy()` | Enter long position |
| `self.sell()` | `close_buy()` | Close long position |
| `self.sell()` (short) | `sell()` | Enter short position |
| `self.buy()` (cover) | `close_sell()` | Close short position |
| `self.position` | `position()` | Current position |

## From Zipline

### Algorithm Structure

**Zipline:**
```python
from zipline.api import order, symbol, record, schedule_function
from zipline.algorithm import TradingAlgorithm

def initialize(context):
    context.asset = symbol('AAPL')
    context.short_window = 10
    context.long_window = 30

def handle_data(context, data):
    short_mavg = data.history(context.asset, 'price', context.short_window, '1d').mean()
    long_mavg = data.history(context.asset, 'price', context.long_window, '1d').mean()
    
    if short_mavg > long_mavg:
        order(context.asset, 100)
    elif short_mavg < long_mavg:
        order(context.asset, -100)
```

**ExPostFacto:**
```elixir
defmodule ZiplinePortStrategy do
  use ExPostFacto.Strategy
  
  def init(opts) do
    {:ok, %{
      short_window: Keyword.get(opts, :short_window, 10),
      long_window: Keyword.get(opts, :long_window, 30),
      price_history: []
    }}
  end
  
  def next(state) do
    price_history = [data().close | state.price_history]
    
    if length(price_history) >= state.long_window do
      short_mavg = calculate_mavg(price_history, state.short_window)
      long_mavg = calculate_mavg(price_history, state.long_window)
      
      cond do
        short_mavg > long_mavg and position() != :long ->
          if position() == :short, do: close_sell()
          buy()
        short_mavg < long_mavg and position() != :short ->
          if position() == :long, do: close_buy()
          sell()
        true ->
          :ok
      end
    end
    
    {:ok, %{state | price_history: price_history}}
  end
  
  defp calculate_mavg(prices, window) do
    prices |> Enum.take(window) |> Enum.sum() |> Kernel./(window)
  end
end
```

## From QuantConnect

### Algorithm Conversion

**QuantConnect (C#):**
```csharp
public class BasicAlgorithm : QCAlgorithm
{
    private SimpleMovingAverage sma;
    
    public override void Initialize()
    {
        SetStartDate(2020, 1, 1);
        SetEndDate(2021, 1, 1);
        SetCash(100000);
        
        AddEquity("SPY", Resolution.Daily);
        sma = SMA("SPY", 14);
    }
    
    public override void OnData(Slice data)
    {
        if (data.Bars.ContainsKey("SPY"))
        {
            var price = data.Bars["SPY"].Close;
            
            if (price > sma && !Portfolio.Invested)
            {
                SetHoldings("SPY", 1.0);
            }
            else if (price < sma && Portfolio.Invested)
            {
                Liquidate("SPY");
            }
        }
    }
}
```

**ExPostFacto:**
```elixir
defmodule QuantConnectPortStrategy do
  use ExPostFacto.Strategy
  
  def init(opts) do
    {:ok, %{
      sma_period: Keyword.get(opts, :sma_period, 14),
      price_history: []
    }}
  end
  
  def next(state) do
    current_price = data().close
    price_history = [current_price | state.price_history]
    
    if length(price_history) >= state.sma_period do
      sma_value = indicator(:sma, price_history, state.sma_period) |> List.first()
      current_position = position()
      
      cond do
        current_price > sma_value and current_position != :long ->
          if current_position == :short, do: close_sell()
          buy()
        current_price < sma_value and current_position != :none ->
          if current_position == :long, do: close_buy()
          if current_position == :short, do: close_sell()
        true ->
          :ok
      end
    end
    
    {:ok, %{state | price_history: price_history}}
  end
end
```

## From Pine Script

### Script Translation

**Pine Script:**
```pine
//@version=5
strategy("SMA Cross", overlay=true)

short_length = input.int(9, "Short SMA Length")
long_length = input.int(21, "Long SMA Length")

short_sma = ta.sma(close, short_length)
long_sma = ta.sma(close, long_length)

if ta.crossover(short_sma, long_sma)
    strategy.entry("Long", strategy.long)

if ta.crossunder(short_sma, long_sma)
    strategy.close("Long")
```

**ExPostFacto:**
```elixir
defmodule PineScriptPortStrategy do
  use ExPostFacto.Strategy
  
  def init(opts) do
    {:ok, %{
      short_length: Keyword.get(opts, :short_length, 9),
      long_length: Keyword.get(opts, :long_length, 21),
      price_history: [],
      short_sma_history: [],
      long_sma_history: []
    }}
  end
  
  def next(state) do
    current_close = data().close
    price_history = [current_close | state.price_history]
    
    short_sma = indicator(:sma, price_history, state.short_length) |> List.first()
    long_sma = indicator(:sma, price_history, state.long_length) |> List.first()
    
    short_sma_history = [short_sma | state.short_sma_history]
    long_sma_history = [long_sma | state.long_sma_history]
    
    # Check for crossovers
    if crossover?(short_sma_history, long_sma_history) do
      buy()
    elsif crossover?(long_sma_history, short_sma_history) do
      close_buy()
    end
    
    {:ok, %{state | 
      price_history: price_history,
      short_sma_history: short_sma_history,
      long_sma_history: long_sma_history
    }}
  end
end
```

## Feature Comparison

### Core Features

| Feature | ExPostFacto | backtesting.py | Backtrader | Zipline | QuantConnect |
|---------|-------------|----------------|------------|---------|--------------|
| **Language** | Elixir | Python | Python | Python | C#/Python |
| **Strategy Types** | MFA + Behaviour | Class-based | Class-based | Function-based | Class-based |
| **Built-in Indicators** | ✅ | ✅ | ✅ | Limited | ✅ |
| **Optimization** | ✅ | ✅ | ✅ | ❌ | ✅ |
| **Walk-Forward** | ✅ | ❌ | ✅ | ❌ | ✅ |
| **Live Trading** | ❌ | ❌ | ✅ | ❌ | ✅ |
| **Multi-Asset** | Limited | ✅ | ✅ | ✅ | ✅ |
| **Data Cleaning** | ✅ | ❌ | ❌ | ✅ | ✅ |
| **Concurrent Processing** | ✅ | ❌ | ❌ | ❌ | ✅ |

### Syntax Mapping

| Concept | ExPostFacto | backtesting.py | Backtrader | Pine Script |
|---------|-------------|----------------|------------|-------------|
| **Buy Signal** | `buy()` | `self.buy()` | `self.buy()` | `strategy.entry("Long", strategy.long)` |
| **Sell Signal** | `sell()` | `self.sell()` | `self.sell()` | `strategy.entry("Short", strategy.short)` |
| **Close Long** | `close_buy()` | `self.sell()` | `self.sell()` | `strategy.close("Long")` |
| **Close Short** | `close_sell()` | `self.buy()` | `self.buy()` | `strategy.close("Short")` |
| **Current Price** | `data().close` | `self.data.Close[-1]` | `self.data.close[0]` | `close` |
| **Position** | `position()` | `self.position` | `self.position` | `strategy.position_size` |
| **SMA** | `indicator(:sma, data, n)` | `self.I(SMA, data, n)` | `bt.indicators.SMA(period=n)` | `ta.sma(close, n)` |
| **Crossover** | `crossover?(a, b)` | `crossover(a, b)` | `a > b and a[-1] <= b[-1]` | `ta.crossover(a, b)` |

## Common Migration Patterns

### 1. Parameter Configuration

**From:** Class attributes or function parameters
```python
class Strategy:
    fast_period = 10
    slow_period = 20
```

**To:** ExPostFacto init options
```elixir
def init(opts) do
  {:ok, %{
    fast_period: Keyword.get(opts, :fast_period, 10),
    slow_period: Keyword.get(opts, :slow_period, 20)
  }}
end
```

### 2. State Management

**From:** Instance variables
```python
def __init__(self):
    self.price_history = []
    self.signals = []
```

**To:** ExPostFacto state map
```elixir
def init(_opts) do
  {:ok, %{
    price_history: [],
    signals: []
  }}
end

def next(state) do
  new_state = %{state | price_history: updated_history}
  {:ok, new_state}
end
```

### 3. Indicator Usage

**From:** Self-updating indicators
```python
def init(self):
    self.sma = self.I(SMA, self.data.Close, 20)

def next(self):
    current_sma = self.sma[-1]
```

**To:** Manual calculation with history
```elixir
def next(state) do
  price_history = [data().close | state.price_history]
  sma_value = indicator(:sma, price_history, 20) |> List.first()
  {:ok, %{state | price_history: price_history}}
end
```

### 4. Optimization

**From:** Built-in optimize functions
```python
result = bt.optimize(param1=range(5, 15), param2=range(20, 30))
```

**To:** ExPostFacto optimize
```elixir
{:ok, result} = ExPostFacto.optimize(
  data, Strategy,
  [param1: 5..14, param2: 20..29]
)
```

## Migration Checklist

When migrating from other libraries:

- [ ] Convert class-based strategies to ExPostFacto Strategy behaviour
- [ ] Translate indicator usage to ExPostFacto indicator framework
- [ ] Convert position management calls
- [ ] Adapt parameter configuration to init/1 pattern
- [ ] Update state management to use immutable state maps
- [ ] Convert optimization code to ExPostFacto format
- [ ] Test with same data to verify equivalent results
- [ ] Update any custom indicators or calculations
- [ ] Adapt data loading and preprocessing
- [ ] Review and update risk management logic

## Getting Help

If you need help migrating specific strategies or have questions about equivalent functionality:

1. Check the [Strategy API Guide](STRATEGY_API.md) for detailed behaviour documentation
2. Review [Best Practices](BEST_PRACTICES.md) for recommended patterns
3. Look at example strategies in `lib/ex_post_facto/example_strategies/`
4. Open an issue on GitHub with your specific migration question

The ExPostFacto community is here to help make your migration as smooth as possible!