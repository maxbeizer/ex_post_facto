ExUnit.start(exclude: [:skip])

defmodule CandleDataHelper do
  def build_candle(action \\ nil, data) do
    high = if action, do: 100.0, else: Keyword.get(data, :high, 0.0)
    low = Keyword.get(data, :low, 0.0)
    open = Keyword.get(data, :open, 0.0)
    close = Keyword.get(data, :close, 0.0)
    timestamp = Keyword.get(data, :timestamp, "")
    %{high: high, low: low, open: open, close: close, timestamp: timestamp}
  end
end
