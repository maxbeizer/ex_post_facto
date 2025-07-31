defmodule ExPostFacto.Position do
  @moduledoc """
  Represents a trading position with size, entry price, and profit/loss tracking.

  A position can be:
  - Long: buying first, then selling to close
  - Short: selling first, then buying to close

  Positions support partial closing and detailed P&L calculations.
  """

  alias ExPostFacto.DataPoint

  @enforce_keys [:id, :symbol, :side, :size, :entry_price, :entry_time, :entry_index]
  defstruct [
    :id,
    :symbol,
    :side,
    :size,
    :entry_price,
    :entry_time,
    :entry_index,
    :entry_data_point,
    current_price: 0.0,
    current_time: nil,
    unrealized_pl: 0.0,
    unrealized_pl_pct: 0.0,
    realized_pl: 0.0,
    realized_pl_pct: 0.0,
    commission_paid: 0.0,
    partial_closes: []
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          symbol: String.t(),
          side: :long | :short,
          size: float(),
          entry_price: float(),
          entry_time: String.t() | nil,
          entry_index: non_neg_integer(),
          entry_data_point: DataPoint.t() | nil,
          current_price: float(),
          current_time: String.t() | nil,
          unrealized_pl: float(),
          unrealized_pl_pct: float(),
          realized_pl: float(),
          realized_pl_pct: float(),
          commission_paid: float(),
          partial_closes: [%{size: float(), price: float(), time: String.t() | nil}]
        }

  @doc """
  Creates a new position.

  ## Examples

      iex> Position.new("AAPL", :long, 100.0, 150.0, "2023-01-01", 0)
      %Position{
        id: "pos_" <> _,
        symbol: "AAPL",
        side: :long,
        size: 100.0,
        entry_price: 150.0,
        entry_time: "2023-01-01",
        entry_index: 0
      }
  """
  @spec new(
          String.t(),
          :long | :short,
          float(),
          float(),
          String.t() | nil,
          non_neg_integer(),
          DataPoint.t() | nil
        ) :: t()
  def new(
        symbol,
        side,
        size,
        entry_price,
        entry_time \\ nil,
        entry_index \\ 0,
        entry_data_point \\ nil
      ) do
    %__MODULE__{
      id: generate_id(),
      symbol: symbol,
      side: side,
      size: size,
      entry_price: entry_price,
      entry_time: entry_time,
      entry_index: entry_index,
      entry_data_point: entry_data_point,
      current_price: entry_price
    }
  end

  @doc """
  Updates the position with current market data.
  """
  @spec update_market_data(t(), float(), String.t() | nil) :: t()
  def update_market_data(position, current_price, current_time \\ nil) do
    unrealized_pl = calculate_unrealized_pl(position, current_price)
    unrealized_pl_pct = calculate_unrealized_pl_pct(position, current_price)

    %{
      position
      | current_price: current_price,
        current_time: current_time,
        unrealized_pl: unrealized_pl,
        unrealized_pl_pct: unrealized_pl_pct
    }
  end

  @doc """
  Partially closes a position.

  Returns a tuple of {updated_position, closed_size, realized_pl}.
  """
  @spec partial_close(t(), float(), float()) :: {t(), float(), float()}
  @spec partial_close(t(), float(), float(), String.t() | nil) :: {t(), float(), float()}
  def partial_close(position, close_size, close_price, close_time \\ nil)

  def partial_close(position, close_size, close_price, close_time) do
    close_size = min(close_size, position.size)

    close_record = %{
      size: close_size,
      price: close_price,
      time: close_time
    }

    # Calculate realized P&L for the closed portion
    realized_pl = calculate_partial_realized_pl(position, close_size, close_price)

    updated_position = %{
      position
      | size: position.size - close_size,
        partial_closes: [close_record | position.partial_closes],
        realized_pl: position.realized_pl + realized_pl
    }

    # Update realized P&L percentage
    updated_position = %{
      updated_position
      | realized_pl_pct: calculate_realized_pl_pct(updated_position)
    }

    # Recalculate unrealized P&L based on new position size
    updated_position =
      if updated_position.size > 0 do
        %{
          updated_position
          | unrealized_pl: calculate_unrealized_pl(updated_position, position.current_price),
            unrealized_pl_pct:
              calculate_unrealized_pl_pct(updated_position, position.current_price)
        }
      else
        %{updated_position | unrealized_pl: 0.0, unrealized_pl_pct: 0.0}
      end

    {updated_position, close_size, realized_pl}
  end

  @doc """
  Fully closes a position.

  Returns a tuple of {closed_position, realized_pl}.
  """
  @spec close(t(), float(), String.t() | nil) :: {t(), float()}
  def close(position, close_price, close_time \\ nil) do
    {updated_position, _closed_size, realized_pl} =
      partial_close(position, position.size, close_price, close_time)

    {updated_position, realized_pl}
  end

  @doc """
  Returns true if the position is long.
  """
  @spec is_long?(t()) :: boolean()
  def is_long?(%{side: :long}), do: true
  def is_long?(_), do: false

  @doc """
  Returns true if the position is short.
  """
  @spec is_short?(t()) :: boolean()
  def is_short?(%{side: :short}), do: true
  def is_short?(_), do: false

  @doc """
  Returns true if the position is fully closed.
  """
  @spec is_closed?(t()) :: boolean()
  def is_closed?(%{size: size}) when size <= 0, do: true
  def is_closed?(_), do: false

  @doc """
  Returns the total profit/loss for the position (realized + unrealized).
  """
  @spec total_pl(t()) :: float()
  def total_pl(position) do
    position.realized_pl + position.unrealized_pl
  end

  @doc """
  Returns the total profit/loss percentage for the position.
  """
  @spec total_pl_pct(t()) :: float()
  def total_pl_pct(position) do
    position.realized_pl_pct + position.unrealized_pl_pct
  end

  # Private functions

  defp generate_id do
    "pos_#{System.unique_integer([:positive])}"
  end

  defp calculate_unrealized_pl(
         %{side: :long, size: size, entry_price: entry_price},
         current_price
       ) do
    (current_price - entry_price) * size
  end

  defp calculate_unrealized_pl(
         %{side: :short, size: size, entry_price: entry_price},
         current_price
       ) do
    (entry_price - current_price) * size
  end

  defp calculate_unrealized_pl_pct(
         %{entry_price: entry_price, size: size} = position,
         current_price
       ) do
    cond do
      entry_price == 0.0 -> 0.0
      size == 0.0 -> 0.0
      true -> calculate_unrealized_pl(position, current_price) / (entry_price * size) * 100.0
    end
  end

  defp calculate_partial_realized_pl(
         %{side: :long, entry_price: entry_price},
         close_size,
         close_price
       ) do
    (close_price - entry_price) * close_size
  end

  defp calculate_partial_realized_pl(
         %{side: :short, entry_price: entry_price},
         close_size,
         close_price
       ) do
    (entry_price - close_price) * close_size
  end

  defp calculate_realized_pl_pct(%{
         realized_pl: realized_pl,
         entry_price: entry_price,
         partial_closes: partial_closes
       }) do
    total_closed_size = Enum.reduce(partial_closes, 0.0, &(&1.size + &2))

    cond do
      entry_price == 0.0 -> 0.0
      total_closed_size == 0.0 -> 0.0
      true -> realized_pl / (entry_price * total_closed_size) * 100.0
    end
  end
end
