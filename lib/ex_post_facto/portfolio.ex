defmodule ExPostFacto.Portfolio do
  @moduledoc """
  Manages a portfolio of positions and orders.

  The portfolio tracks:
  - Current positions (open trades)
  - Pending orders
  - Order history
  - Position history
  - Portfolio-level metrics
  """

  alias ExPostFacto.{Position, Order}

  defstruct positions: %{},
            orders: %{},
            order_history: [],
            position_history: [],
            equity: 0.0,
            available_cash: 0.0,
            margin_used: 0.0,
            total_commission: 0.0

  @type t :: %__MODULE__{
          positions: %{String.t() => Position.t()},
          orders: %{String.t() => Order.t()},
          order_history: [Order.t()],
          position_history: [Position.t()],
          equity: float(),
          available_cash: float(),
          margin_used: float(),
          total_commission: float()
        }

  @doc """
  Creates a new empty portfolio.
  """
  @spec new(float()) :: t()
  def new(starting_equity \\ 0.0) do
    %__MODULE__{
      equity: starting_equity,
      available_cash: starting_equity
    }
  end

  @doc """
  Adds an order to the portfolio.
  """
  @spec add_order(t(), Order.t()) :: t()
  def add_order(portfolio, order) do
    %{portfolio | orders: Map.put(portfolio.orders, order.id, order)}
  end

  @doc """
  Removes an order from the portfolio and adds it to history.
  """
  @spec remove_order(t(), String.t()) :: t()
  def remove_order(portfolio, order_id) do
    case Map.pop(portfolio.orders, order_id) do
      {nil, _} ->
        portfolio

      {order, updated_orders} ->
        %{
          portfolio
          | orders: updated_orders,
            order_history: [order | portfolio.order_history]
        }
    end
  end

  @doc """
  Adds a position to the portfolio.
  """
  @spec add_position(t(), Position.t()) :: t()
  def add_position(portfolio, position) do
    %{portfolio | positions: Map.put(portfolio.positions, position.id, position)}
  end

  @doc """
  Updates an existing position in the portfolio.
  """
  @spec update_position(t(), String.t(), Position.t()) :: t()
  def update_position(portfolio, position_id, updated_position) do
    if Map.has_key?(portfolio.positions, position_id) do
      %{portfolio | positions: Map.put(portfolio.positions, position_id, updated_position)}
    else
      portfolio
    end
  end

  @doc """
  Removes a position from the portfolio and adds it to history.
  """
  @spec remove_position(t(), String.t()) :: t()
  def remove_position(portfolio, position_id) do
    case Map.pop(portfolio.positions, position_id) do
      {nil, _} ->
        portfolio

      {position, updated_positions} ->
        %{
          portfolio
          | positions: updated_positions,
            position_history: [position | portfolio.position_history]
        }
    end
  end

  @doc """
  Gets all open positions.
  """
  @spec get_positions(t()) :: [Position.t()]
  def get_positions(portfolio) do
    Map.values(portfolio.positions)
  end

  @doc """
  Gets all positions for a specific symbol.
  """
  @spec get_positions_for_symbol(t(), String.t()) :: [Position.t()]
  def get_positions_for_symbol(portfolio, symbol) do
    portfolio.positions
    |> Map.values()
    |> Enum.filter(&(&1.symbol == symbol))
  end

  @doc """
  Gets all long positions.
  """
  @spec get_long_positions(t()) :: [Position.t()]
  def get_long_positions(portfolio) do
    portfolio.positions
    |> Map.values()
    |> Enum.filter(&Position.is_long?/1)
  end

  @doc """
  Gets all short positions.
  """
  @spec get_short_positions(t()) :: [Position.t()]
  def get_short_positions(portfolio) do
    portfolio.positions
    |> Map.values()
    |> Enum.filter(&Position.is_short?/1)
  end

  @doc """
  Gets all pending orders.
  """
  @spec get_pending_orders(t()) :: [Order.t()]
  def get_pending_orders(portfolio) do
    portfolio.orders
    |> Map.values()
    |> Enum.filter(&Order.is_pending?/1)
  end

  @doc """
  Gets all pending orders for a specific symbol.
  """
  @spec get_pending_orders_for_symbol(t(), String.t()) :: [Order.t()]
  def get_pending_orders_for_symbol(portfolio, symbol) do
    portfolio.orders
    |> Map.values()
    |> Enum.filter(&(&1.symbol == symbol && Order.is_pending?(&1)))
  end

  @doc """
  Calculates the total position size for a symbol (net long/short).
  """
  @spec get_net_position_size(t(), String.t()) :: float()
  def get_net_position_size(portfolio, symbol) do
    portfolio.positions
    |> Map.values()
    |> Enum.filter(&(&1.symbol == symbol))
    |> Enum.reduce(0.0, fn position, acc ->
      case position.side do
        :long -> acc + position.size
        :short -> acc - position.size
      end
    end)
  end

  @doc """
  Calculates total unrealized P&L across all positions.
  """
  @spec total_unrealized_pl(t()) :: float()
  def total_unrealized_pl(portfolio) do
    portfolio.positions
    |> Map.values()
    |> Enum.reduce(0.0, &(&1.unrealized_pl + &2))
  end

  @doc """
  Calculates total realized P&L across all positions.
  """
  @spec total_realized_pl(t()) :: float()
  def total_realized_pl(portfolio) do
    current_realized =
      portfolio.positions
      |> Map.values()
      |> Enum.reduce(0.0, &(&1.realized_pl + &2))

    historical_realized =
      portfolio.position_history
      |> Enum.reduce(0.0, &(&1.realized_pl + &2))

    current_realized + historical_realized
  end

  @doc """
  Calculates total P&L (realized + unrealized).
  """
  @spec total_pl(t()) :: float()
  def total_pl(portfolio) do
    total_realized_pl(portfolio) + total_unrealized_pl(portfolio)
  end

  @doc """
  Updates portfolio equity based on current positions.
  """
  @spec update_equity(t(), float()) :: t()
  def update_equity(portfolio, starting_cash) do
    total_pl = total_pl(portfolio)
    new_equity = starting_cash + total_pl

    %{portfolio | equity: new_equity}
  end

  @doc """
  Processes market data update for all positions.
  """
  @spec update_market_data(t(), String.t(), float(), String.t() | nil) :: t()
  def update_market_data(portfolio, symbol, current_price, current_time \\ nil) do
    updated_positions =
      portfolio.positions
      |> Enum.map(fn {id, position} ->
        if position.symbol == symbol do
          {id, Position.update_market_data(position, current_price, current_time)}
        else
          {id, position}
        end
      end)
      |> Map.new()

    %{portfolio | positions: updated_positions}
  end

  @doc """
  Returns true if the portfolio has any open positions.
  """
  @spec has_positions?(t()) :: boolean()
  def has_positions?(portfolio) do
    map_size(portfolio.positions) > 0
  end

  @doc """
  Returns true if the portfolio has any pending orders.
  """
  @spec has_pending_orders?(t()) :: boolean()
  def has_pending_orders?(portfolio) do
    portfolio.orders
    |> Map.values()
    |> Enum.any?(&Order.is_pending?/1)
  end

  @doc """
  Gets portfolio summary statistics.
  """
  @spec get_summary(t()) :: %{
          total_positions: non_neg_integer(),
          total_pending_orders: non_neg_integer(),
          total_pl: float(),
          total_unrealized_pl: float(),
          total_realized_pl: float(),
          equity: float(),
          available_cash: float()
        }
  def get_summary(portfolio) do
    %{
      total_positions: map_size(portfolio.positions),
      total_pending_orders: length(get_pending_orders(portfolio)),
      total_pl: total_pl(portfolio),
      total_unrealized_pl: total_unrealized_pl(portfolio),
      total_realized_pl: total_realized_pl(portfolio),
      equity: portfolio.equity,
      available_cash: portfolio.available_cash
    }
  end
end
