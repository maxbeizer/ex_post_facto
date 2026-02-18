# GitHub Copilot Instructions for ExPostFacto

## Build & Test Commands

- **Format**: `mix format`
- **Compile (strict)**: `mix compile --warnings-as-errors`
- **Test**: `mix test`
- **Docs**: `mix docs`

Always run `mix format` after code changes. The project uses `.formatter.exs` with standard Elixir formatting.

## Code Standards

- `@moduledoc` and `@doc` on all public modules and functions
- `@spec` type annotations on all public functions
- snake_case for functions/variables, PascalCase for modules
- Prefer pattern matching over conditionals
- Use `with` for complex nested operations
- Use `|>` pipe operator for data transformations
- `{:ok, result}` / `{:error, reason}` tuples for error handling
- `!` suffix for functions that raise (e.g., `backtest!`)
- Fix all compiler warnings — there should be zero

## Project Overview

ExPostFacto is a **backtesting library for trading strategies** in Elixir.
It is pre-1.0 and under active development.

## Architecture

### Core Backtest Flow

1. Market data (OHLC maps or CSV path) → `ExPostFacto.backtest/3`
2. Data is cleaned/validated → `InputData.munge/1` normalizes each point
3. Strategy applied to each data point pair via `Enum.chunk_every(2, 1, :discard)`
4. Strategy returns actions: `:buy`, `:sell`, `:close_buy`, `:close_sell`
5. `Result.compile/2` builds trade pairs and calculates statistics
6. Returns `{:ok, %Output{}}` with `result` field containing all metrics

**Important**: Only **completed round-trip trades** produce P&L. A `:buy` must
be paired with a `:close_buy` (or `:sell` with `:close_sell`) to form a
`TradePair`. A buy-and-hold strategy will show $0 P&L and 0 trades.

### Two Strategy Formats

1. **MFA tuple** `{Module, :function, args}` — simple, stateless:
   ```elixir
   def call(data, result) do
     if data.close > 105.0, do: :close_buy, else: :buy
   end
   ```

2. **Strategy behaviour** `{Module, opts}` — stateful, uses `StrategyContext` Agent:
   ```elixir
   use ExPostFacto.Strategy
   def init(opts), do: {:ok, %{}}
   def next(state), do: {:ok, state}  # use buy(), sell(), data(), position()
   ```
   Note: `StrategyContext` is a singleton named Agent, so behaviour strategies
   cannot run in parallel. The optimizer falls back to sequential for these.

### Key Modules

| Module | Purpose |
|--------|---------|
| `ExPostFacto` | Main entry point: `backtest/3`, `backtest!/3`, `optimize/4`, `backtest_stream/3` |
| `ExPostFacto.Result` | Result compilation with concurrent `Task.async_stream` for metrics |
| `ExPostFacto.InputData` | Data normalization (field aliases, timestamp parsing) |
| `ExPostFacto.DataPoint` | Struct: `{datum, action, index}` |
| `ExPostFacto.Output` | Final output struct wrapping data + strategy + result |
| `ExPostFacto.Validation` | OHLC validation, data cleaning, strategy validation |
| `ExPostFacto.Indicators` | 6 indicators: SMA, EMA, RSI, MACD, Bollinger Bands, ATR |
| `ExPostFacto.Strategy` | Behaviour macro with `init/1`, `next/1`, helpers |
| `ExPostFacto.StrategyContext` | Agent holding current data/position for Strategy behaviour |
| `ExPostFacto.Optimizer` | Grid search, random search, walk-forward analysis |
| `ExPostFacto.Streaming` | Chunked backtest processing for large datasets |

### Trade Statistics (`ExPostFacto.TradeStats.*`)

- `CompilePairs` — matches enter/exit points into `TradePair` structs
- `TradePair` — struct with enter/exit points and running balance
- `TotalProfitAndLoss`, `WinRate`, `DrawDown`, `TradeDuration`, `TradePercentage`
- `FinancialRatios` — Sharpe, Sortino, Calmar, CAGR, annual volatility
- `ProfitMetrics` — profit factor, expectancy, gross P&L
- `SystemQuality` — SQN with Van Tharp interpretation
- `KellyCriterion` — Kelly %, fractional Kelly, risk of ruin
- `MarketRisk` — alpha, beta, information ratio (uses simplified estimates, not real benchmark data)

### Modules Not Yet Integrated Into Backtest Loop

These modules are implemented and tested but operate standalone — they are
**not wired into** `backtest/3`:

- `ExPostFacto.Portfolio` — position management, equity tracking
- `ExPostFacto.Position` — long/short, partial close, P&L tracking
- `ExPostFacto.Order` — market/limit/stop/stop-limit with fill logic

### Roadmap / Known Stubs

- JSON data loading — returns error asking for Jason library
- GenStage streaming pipeline — returns `{:error, "not yet implemented"}`
- Additional technical indicators beyond the current 6
- Integration of Portfolio/Position/Order into the backtest loop

## Testing Structure

Tests mirror `lib/` structure. Key test helpers:

- `CandleDataHelper` — generates mock market data
- Tests are mostly async (`async: true`)

## Example Strategies

- `BuyBuyBuy`, `SellSellSell`, `Noop` — MFA test strategies
- `SimpleBuyHold`, `SmaStrategy`, `RSIMeanReversionStrategy` — Strategy behaviour
- `BollingerBandStrategy`, `BreakoutStrategy`, `AdvancedMacdStrategy` — Strategy behaviour
