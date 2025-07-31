ExUnit.start(exclude: [:skip])

defmodule CandleDataHelper do
  def build_candle(action \\ nil, data) do
    # Get base values with proper defaults that ensure valid OHLC relationships
    open = Keyword.get(data, :open, 1.0)
    close = Keyword.get(data, :close, 1.0)

    # Ensure high is at least as high as open and close
    default_high = max(open, close)
    high = if action, do: 100.0, else: Keyword.get(data, :high, default_high)

    # Ensure low is at most as low as open and close
    default_low = min(open, close)
    low = Keyword.get(data, :low, default_low)

    timestamp = Keyword.get(data, :timestamp, "")
    %{high: high, low: low, open: open, close: close, timestamp: timestamp}
  end
end
