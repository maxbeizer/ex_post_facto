# GitHub Copilot Instructions for ExPostFacto

## Code Formatting and Standards

Always run `mix format` after making any code changes to ensure consistent formatting across the codebase. The project uses the standard Elixir formatter configuration defined in `.formatter.exs`.

Follow these Elixir best practices:

- Use descriptive module and function names
- Include proper `@moduledoc` and `@doc` attributes for all public modules and functions
- Use `@spec` type annotations for all public functions
- Follow the Elixir naming conventions (snake_case for functions/variables, PascalCase for modules)
- Prefer pattern matching over conditional statements when possible
- Use `with` statements for complex nested operations
- Keep functions small and focused on a single responsibility
- Use `|>` pipe operator for data transformations
- Handle errors explicitly with `{:ok, result}` and `{:error, reason}` tuples
- Use `!` suffix for functions that raise exceptions (e.g., `backtest!`)

## Project Structure and Architecture

ExPostFacto is a **backtesting library for trading strategies** written in Elixir. The application structure is organized as follows:

### Core Modules

- **`ExPostFacto`** (main entry point): Contains the primary `backtest/3` and `backtest!/3` functions that execute trading strategies against historical data
- **`ExPostFacto.Result`**: Manages backtesting results and statistics compilation, including trade pairs, profit/loss calculations, and performance metrics
- **`ExPostFacto.DataPoint`**: Represents individual price data points with actions (buy, sell, close_buy, close_sell)
- **`ExPostFacto.InputData`**: Handles data munging and preprocessing of input market data
- **`ExPostFacto.Output`**: Contains the final output structure returned from backtesting operations

### Trading Strategy Framework

The library supports pluggable trading strategies through a module-function-arguments tuple pattern `{Module, :function, args}`. Example strategies are provided in:

- **`ExPostFacto.ExampleStrategies.BuyBuyBuy`**: Always buys (for testing)
- **`ExPostFacto.ExampleStrategies.SellSellSell`**: Always sells (for testing)
- **`ExPostFacto.ExampleStrategies.Noop`**: No-operation strategy (for testing)

### Trade Statistics Engine

The `ExPostFacto.TradeStats` namespace contains modules for calculating various performance metrics:

- **`CompilePairs`**: Groups buy/sell actions into trade pairs for analysis
- **`DrawDown`**: Calculates maximum and average drawdown percentages and durations
- **`Duration`**: Handles date/time calculations for trade and drawdown durations
- **`TotalProfitAndLoss`**: Computes cumulative profit and loss from trade pairs
- **`TradeDuration`**: Calculates maximum and average trade durations
- **`TradePercentage`**: Determines best, worst, and average trade performance percentages
- **`TradePair`**: Represents matched enter/exit positions with balance calculations
- **`WinRate`**: Computes win rate and win count statistics

### Application Flow

1. **Data Input**: Market data (OHLC) is fed into the `backtest/3` function
2. **Strategy Application**: A trading strategy function is applied to each data point
3. **Action Generation**: Strategy generates actions (`:buy`, `:sell`, `:close_buy`, `:close_sell`)
4. **Result Compilation**: Trade pairs are compiled and statistics are calculated
5. **Output Generation**: Final results with comprehensive trading metrics are returned

### Key Design Patterns

- **Functional Programming**: Heavy use of immutable data structures and pure functions
- **Pipeline Processing**: Extensive use of the pipe operator for data transformations
- **Pattern Matching**: Used throughout for control flow and data extraction
- **Struct-based Data**: Well-defined structs for `Result`, `DataPoint`, `TradePair`, etc.
- **Error Handling**: Consistent `{:ok, result}` / `{:error, reason}` pattern with bang variants

### Testing Structure

Tests are organized to mirror the lib structure:

- Unit tests for individual modules
- Integration tests for end-to-end backtesting scenarios
- Test helpers for generating mock market data (`CandleDataHelper`)

### Future Enhancements (TODOs)

Based on comments in the code, planned improvements include:

- Making trade statistics calculations concurrent
- Adding more comprehensive backtesting metrics similar to Python libraries
- Expanding the strategy framework capabilities

## Development Guidelines

When contributing to this project:

1. **Always format code** with `mix format` before committing
2. **Add comprehensive tests** for new functionality
3. **Include proper documentation** with examples
4. **Follow the existing architectural patterns** (functional, immutable)
5. **Use descriptive names** that clearly indicate purpose
6. **Handle edge cases** explicitly (empty data, nil values, etc.)
7. **Maintain backward compatibility** when modifying public APIs
8. **Add type specs** for all public functions
9. **Consider performance implications** for large datasets
10. **Test with real market data** when possible

## Code Examples

### Strategy Implementation

```elixir
defmodule MyStrategy do
  @doc "Simple moving average crossover strategy"
  @spec call(market_data :: map(), result :: ExPostFacto.Result.t()) :: ExPostFacto.action()
  def call(%{close: price}, %{data_points: data_points}) do
    # Strategy logic here
    :buy  # or :sell, :close_buy, :close_sell
  end
end
```

### Usage Pattern

```elixir
{:ok, output} = ExPostFacto.backtest(
  market_data,
  {MyStrategy, :call, []},
  starting_balance: 10_000.0
)

IO.inspect(output.result.total_profit_and_loss)
```

Remember to always run `mix format` and ensure tests pass with `mix test` before submitting any changes.
