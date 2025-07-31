# ExPostFacto

A comprehensive backtesting library for trading strategies written in Elixir.

## Features

- **Multiple Input Formats**: Support for CSV files, JSON, and lists of maps
- **Data Validation**: Comprehensive OHLCV data validation with detailed error messages  
- **Data Cleaning**: Automatic removal of invalid data, sorting, and duplicate handling
- **Enhanced Timestamp Handling**: Support for multiple timestamp formats (ISO 8601, Unix, date strings)
- **Flexible Strategy Framework**: Pluggable trading strategies with easy-to-use interfaces
- **Comprehensive Statistics**: Detailed trade analysis and performance metrics

## Quick Start

```elixir
# Load data from CSV file and run backtest
{:ok, output} = ExPostFacto.backtest(
  "market_data.csv", 
  {MyStrategy, :call, []}, 
  starting_balance: 100_000.0
)

# Or use data directly
data = [
  %{open: 100.0, high: 105.0, low: 98.0, close: 102.0, timestamp: "2023-01-01"},
  %{open: 102.0, high: 108.0, low: 101.0, close: 106.0, timestamp: "2023-01-02"}
]

{:ok, output} = ExPostFacto.backtest(data, {MyStrategy, :call, []})
```

## Data Validation and Cleaning

```elixir
# Validate your data
case ExPostFacto.validate_data(data) do
  :ok -> IO.puts("Data is valid!")
  {:error, reason} -> IO.puts("Validation error: #{reason}")
end

# Clean messy data
{:ok, clean_data} = ExPostFacto.clean_data(dirty_data)
```

See [ENHANCED_DATA_HANDLING_EXAMPLES.md](ENHANCED_DATA_HANDLING_EXAMPLES.md) for detailed usage examples.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ex_post_facto` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_post_facto, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/ex_post_facto>.
