# Enhanced Data Handling Usage Examples

This file demonstrates the new enhanced data handling and validation features in ExPostFacto.

## Data Validation

```elixir
# Validate OHLCV data structure and values
valid_data = [
  %{open: 100.0, high: 105.0, low: 98.0, close: 102.0, volume: 1000000},
  %{open: 102.0, high: 108.0, low: 101.0, close: 106.0, volume: 1200000}
]

case ExPostFacto.validate_data(valid_data) do
  :ok -> IO.puts("Data is valid!")
  {:error, reason} -> IO.puts("Validation error: #{reason}")
end

# Example with invalid data
invalid_data = [%{open: 100.0, high: 95.0, low: 98.0, close: 102.0}]  # high < low
{:error, "data point 0: invalid OHLC data: high (95.0) must be >= low (98.0)"} = 
  ExPostFacto.validate_data(invalid_data)
```

## Data Cleaning

```elixir
# Clean messy data - removes invalid points, sorts by timestamp, removes duplicates
dirty_data = [
  %{open: 100.0, high: 105.0, low: 98.0, close: 102.0, timestamp: "2023-01-03"},
  %{open: nil, high: 105.0, low: 98.0, close: 102.0, timestamp: "2023-01-02"},    # invalid
  %{open: 100.0, high: 95.0, low: 98.0, close: 102.0, timestamp: "2023-01-01"},  # invalid
  %{open: 106.0, high: 110.0, low: 104.0, close: 108.0, timestamp: "2023-01-04"}
]

{:ok, clean_data} = ExPostFacto.clean_data(dirty_data)
# Result: 2 valid data points, sorted by timestamp
```

## Multiple Input Formats

```elixir
# 1. CSV file path
{:ok, output} = ExPostFacto.backtest("path/to/market_data.csv", {MyStrategy, :call, []})

# 2. List of maps (existing functionality)
data = [%{open: 100.0, high: 105.0, low: 98.0, close: 102.0}]
{:ok, output} = ExPostFacto.backtest(data, {MyStrategy, :call, []})

# 3. JSON string
json_data = ~s([{"open": 100.0, "high": 105.0, "low": 98.0, "close": 102.0}])
{:ok, output} = ExPostFacto.backtest(json_data, {MyStrategy, :call, []})
```

## Enhanced Timestamp Handling

```elixir
# Supports multiple timestamp formats
mixed_data = [
  %{open: 100.0, high: 105.0, low: 98.0, close: 102.0, timestamp: "2023-01-01"},           # Date
  %{open: 102.0, high: 108.0, low: 101.0, close: 106.0, timestamp: "2023-01-02T12:00:00Z"}, # ISO 8601
  %{open: 106.0, high: 110.0, low: 104.0, close: 108.0, t: "1672790400"}                    # Unix timestamp
]

# Timestamps are automatically normalized to DateTime structs when possible
alias ExPostFacto.InputData
processed = Enum.map(mixed_data, &InputData.munge/1)
# Each processed item will have normalized timestamps
```

## CSV Format Support

ExPostFacto automatically handles common CSV formats:

```csv
Date,Open,High,Low,Close,Volume
2023-01-01,100.0,105.0,98.0,102.0,1000000
2023-01-02,102.0,108.0,101.0,106.0,1200000
```

Or with adjusted close:

```csv
Date,Open,High,Low,Close,Adj Close,Volume
2023-01-01,100.0,105.0,98.0,102.0,101.5,1000000
2023-01-02,102.0,108.0,101.0,106.0,105.8,1200000
```

## Flexible Options

```elixir
# Skip validation for performance or if you trust your data
{:ok, output} = ExPostFacto.backtest(data, strategy, validate_data: false)

# Skip cleaning if data is already clean
{:ok, output} = ExPostFacto.backtest(data, strategy, clean_data: false)

# Combine with other options
{:ok, output} = ExPostFacto.backtest(
  "market_data.csv", 
  {MyStrategy, :call, []}, 
  starting_balance: 100_000.0,
  validate_data: true,
  clean_data: true
)
```

## Error Handling

```elixir
# Detailed error messages for debugging
{:error, "data point 5: missing required OHLC fields"} = 
  ExPostFacto.validate_data(invalid_data)

{:error, "failed to load data: failed to read file: enoent"} = 
  ExPostFacto.backtest("nonexistent.csv", strategy)
```