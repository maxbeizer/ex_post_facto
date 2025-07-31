defmodule ExPostFacto.Order do
  @moduledoc """
  Represents different types of trading orders.

  Supports:
  - Market orders (immediate execution)
  - Limit orders (execute at specific price or better)
  - Stop orders (execute when price reaches stop level)
  - Stop-limit orders (becomes limit order when stop triggered)
  - Orders with stop-loss and take-profit levels
  """

  @enforce_keys [:id, :symbol, :type, :side, :size]
  defstruct [
    :id,
    :symbol,
    :type,
    :side,
    :size,
    :limit_price,
    :stop_price,
    :stop_loss,
    :take_profit,
    :time_in_force,
    :created_at,
    :created_index,
    :filled_at,
    :filled_index,
    :filled_price,
    :filled_size,
    status: :pending,
    commission: 0.0
  ]

  @type order_type :: :market | :limit | :stop | :stop_limit
  @type order_side :: :buy | :sell
  @type order_status :: :pending | :filled | :partially_filled | :cancelled | :rejected
  @type time_in_force :: :day | :gtc | :ioc | :fok

  @type t :: %__MODULE__{
          id: String.t(),
          symbol: String.t(),
          type: order_type(),
          side: order_side(),
          size: float(),
          limit_price: float() | nil,
          stop_price: float() | nil,
          stop_loss: float() | nil,
          take_profit: float() | nil,
          time_in_force: time_in_force() | nil,
          created_at: String.t() | nil,
          created_index: non_neg_integer() | nil,
          filled_at: String.t() | nil,
          filled_index: non_neg_integer() | nil,
          filled_price: float() | nil,
          filled_size: float() | nil,
          status: order_status(),
          commission: float()
        }

  @doc """
  Creates a new market order.

  ## Examples

      iex> Order.market("AAPL", :buy, 100.0)
      %Order{
        type: :market,
        symbol: "AAPL",
        side: :buy,
        size: 100.0,
        status: :pending
      }
  """
  @spec market(String.t(), order_side(), float(), keyword()) :: t()
  def market(symbol, side, size, opts \\ []) do
    %__MODULE__{
      id: generate_id(),
      symbol: symbol,
      type: :market,
      side: side,
      size: size,
      stop_loss: Keyword.get(opts, :stop_loss),
      take_profit: Keyword.get(opts, :take_profit),
      time_in_force: Keyword.get(opts, :time_in_force, :day),
      created_at: Keyword.get(opts, :created_at),
      created_index: Keyword.get(opts, :created_index)
    }
  end

  @doc """
  Creates a new limit order.

  ## Examples

      iex> Order.limit("AAPL", :buy, 100.0, 149.50)
      %Order{
        type: :limit,
        symbol: "AAPL",
        side: :buy,
        size: 100.0,
        limit_price: 149.50,
        status: :pending
      }
  """
  @spec limit(String.t(), order_side(), float(), float(), keyword()) :: t()
  def limit(symbol, side, size, limit_price, opts \\ []) do
    %__MODULE__{
      id: generate_id(),
      symbol: symbol,
      type: :limit,
      side: side,
      size: size,
      limit_price: limit_price,
      stop_loss: Keyword.get(opts, :stop_loss),
      take_profit: Keyword.get(opts, :take_profit),
      time_in_force: Keyword.get(opts, :time_in_force, :gtc),
      created_at: Keyword.get(opts, :created_at),
      created_index: Keyword.get(opts, :created_index)
    }
  end

  @doc """
  Creates a new stop order.

  ## Examples

      iex> Order.stop("AAPL", :sell, 100.0, 145.00)
      %Order{
        type: :stop,
        symbol: "AAPL",
        side: :sell,
        size: 100.0,
        stop_price: 145.00,
        status: :pending
      }
  """
  @spec stop(String.t(), order_side(), float(), float(), keyword()) :: t()
  def stop(symbol, side, size, stop_price, opts \\ []) do
    %__MODULE__{
      id: generate_id(),
      symbol: symbol,
      type: :stop,
      side: side,
      size: size,
      stop_price: stop_price,
      time_in_force: Keyword.get(opts, :time_in_force, :gtc),
      created_at: Keyword.get(opts, :created_at),
      created_index: Keyword.get(opts, :created_index)
    }
  end

  @doc """
  Creates a new stop-limit order.

  ## Examples

      iex> Order.stop_limit("AAPL", :sell, 100.0, 145.00, 144.50)
      %Order{
        type: :stop_limit,
        symbol: "AAPL",
        side: :sell,
        size: 100.0,
        stop_price: 145.00,
        limit_price: 144.50,
        status: :pending
      }
  """
  @spec stop_limit(String.t(), order_side(), float(), float(), float(), keyword()) :: t()
  def stop_limit(symbol, side, size, stop_price, limit_price, opts \\ []) do
    %__MODULE__{
      id: generate_id(),
      symbol: symbol,
      type: :stop_limit,
      side: side,
      size: size,
      stop_price: stop_price,
      limit_price: limit_price,
      time_in_force: Keyword.get(opts, :time_in_force, :gtc),
      created_at: Keyword.get(opts, :created_at),
      created_index: Keyword.get(opts, :created_index)
    }
  end

  @doc """
  Checks if an order can be filled at the given market price.
  """
  @spec can_fill?(t(), float()) :: boolean()
  def can_fill?(%{type: :market, status: :pending}, _price), do: true

  def can_fill?(
        %{type: :limit, side: :buy, limit_price: limit_price, status: :pending},
        market_price
      ) do
    market_price <= limit_price
  end

  def can_fill?(
        %{type: :limit, side: :sell, limit_price: limit_price, status: :pending},
        market_price
      ) do
    market_price >= limit_price
  end

  def can_fill?(
        %{type: :stop, side: :buy, stop_price: stop_price, status: :pending},
        market_price
      ) do
    market_price >= stop_price
  end

  def can_fill?(
        %{type: :stop, side: :sell, stop_price: stop_price, status: :pending},
        market_price
      ) do
    market_price <= stop_price
  end

  def can_fill?(
        %{
          type: :stop_limit,
          side: :buy,
          stop_price: stop_price,
          limit_price: limit_price,
          status: :pending
        },
        market_price
      ) do
    market_price >= stop_price && market_price <= limit_price
  end

  def can_fill?(
        %{
          type: :stop_limit,
          side: :sell,
          stop_price: stop_price,
          limit_price: limit_price,
          status: :pending
        },
        market_price
      ) do
    market_price <= stop_price && market_price >= limit_price
  end

  def can_fill?(_, _), do: false

  @doc """
  Fills an order at the given price and time.
  """
  @spec fill(t(), float(), String.t() | nil, non_neg_integer() | nil, float() | nil) :: t()
  def fill(order, fill_price, fill_time \\ nil, fill_index \\ nil, commission \\ 0.0) do
    %{
      order
      | status: :filled,
        filled_price: fill_price,
        filled_size: order.size,
        filled_at: fill_time,
        filled_index: fill_index,
        commission: commission
    }
  end

  @doc """
  Partially fills an order.
  """
  @spec partial_fill(
          t(),
          float(),
          float(),
          String.t() | nil,
          non_neg_integer() | nil,
          float() | nil
        ) :: t()
  def partial_fill(
        order,
        fill_size,
        fill_price,
        fill_time \\ nil,
        fill_index \\ nil,
        commission \\ 0.0
      ) do
    filled_size = (order.filled_size || 0.0) + fill_size

    status =
      if filled_size >= order.size do
        :filled
      else
        :partially_filled
      end

    %{
      order
      | status: status,
        filled_price: fill_price,
        filled_size: filled_size,
        filled_at: fill_time,
        filled_index: fill_index,
        commission: order.commission + commission
    }
  end

  @doc """
  Cancels an order.
  """
  @spec cancel(t()) :: t()
  def cancel(order) do
    %{order | status: :cancelled}
  end

  @doc """
  Returns true if the order is pending.
  """
  @spec is_pending?(t()) :: boolean()
  def is_pending?(%{status: :pending}), do: true
  def is_pending?(_), do: false

  @doc """
  Returns true if the order is filled.
  """
  @spec is_filled?(t()) :: boolean()
  def is_filled?(%{status: :filled}), do: true
  def is_filled?(_), do: false

  @doc """
  Returns true if the order is partially filled.
  """
  @spec is_partially_filled?(t()) :: boolean()
  def is_partially_filled?(%{status: :partially_filled}), do: true
  def is_partially_filled?(_), do: false

  @doc """
  Returns the remaining size to be filled.
  """
  @spec remaining_size(t()) :: float()
  def remaining_size(%{size: size, filled_size: nil}), do: size
  def remaining_size(%{size: size, filled_size: filled_size}), do: size - filled_size

  # Private functions

  defp generate_id do
    "order_#{System.unique_integer([:positive])}"
  end
end
