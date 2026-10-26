defmodule FoodDeliveryBackend.OrderBook do
  @moduledoc """
  The in-memory order book.

  Like `Catalogue`, an `OrderBook` is a plain value: orders are kept in a
  map keyed by id, and ids are handed out from a counter so they are
  unique and deterministic within one book. Placing an order validates
  against a `Catalogue` — the restaurant must exist and be open, every
  line must name an available item from that restaurant, and the items
  total must clear the restaurant's minimum order. Nothing is mutated on
  error.
  """

  alias FoodDeliveryBackend.Catalogue
  alias FoodDeliveryBackend.Order
  alias FoodDeliveryBackend.OrderLine

  defstruct orders: %{}, next_order_id: 1

  @type t :: %__MODULE__{
          orders: %{String.t() => Order.t()},
          next_order_id: pos_integer()
        }

  @doc "Returns an empty order book."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Places an order against a catalogue.

  `lines` is a list of `%{item_id: id, quantity: n}` maps. Returns
  `{:ok, book, order}` or an error:

    * `:restaurant_not_found` — unknown restaurant id
    * `:restaurant_closed` — the restaurant is not open
    * `:empty_order` — no lines given
    * `:item_not_found` — a line names an unknown menu item
    * `:item_wrong_restaurant` — a line names another restaurant's item
    * `:item_unavailable` — a line names a sold-out item
    * `:below_minimum_order` — the items total is under the minimum
    * a string — an invalid quantity
  """
  @spec place_order(t(), Catalogue.t(), String.t(), [map()]) ::
          {:ok, t(), Order.t()} | {:error, atom() | String.t()}
  def place_order(%__MODULE__{} = book, %Catalogue{} = catalogue, restaurant_id, lines)
      when is_list(lines) do
    with {:ok, restaurant} <- fetch_restaurant(catalogue, restaurant_id),
         :ok <- check_open(restaurant),
         {:ok, order_lines} <- resolve_lines(catalogue, restaurant_id, lines),
         {:ok, order} <-
           Order.new(%{
             id: "o#{book.next_order_id}",
             restaurant_id: restaurant_id,
             lines: order_lines,
             delivery_fee_cents: restaurant.delivery_fee_cents,
             min_order_cents: restaurant.min_order_cents
           }) do
      updated = %{
        book
        | orders: Map.put(book.orders, order.id, order),
          next_order_id: book.next_order_id + 1
      }

      {:ok, updated, order}
    end
  end

  @doc "Fetches an order by id, or `nil`."
  @spec get_order(t(), String.t()) :: Order.t() | nil
  def get_order(%__MODULE__{} = book, id) do
    Map.get(book.orders, id)
  end

  @doc "Lists all orders, sorted by id."
  @spec list_orders(t()) :: [Order.t()]
  def list_orders(%__MODULE__{} = book) do
    book.orders |> Map.values() |> Enum.sort_by(& &1.id)
  end

  @doc "Lists a restaurant's orders, sorted by id."
  @spec list_orders_for_restaurant(t(), String.t()) :: [Order.t()]
  def list_orders_for_restaurant(%__MODULE__{} = book, restaurant_id) do
    book |> list_orders() |> Enum.filter(&(&1.restaurant_id == restaurant_id))
  end

  @doc "Lists orders in a given lifecycle status, sorted by id."
  @spec list_orders_by_status(t(), Order.status()) :: [Order.t()]
  def list_orders_by_status(%__MODULE__{} = book, status) do
    book |> list_orders() |> Enum.filter(&(&1.status == status))
  end

  @doc """
  Advances an order one lifecycle step. Returns `{:ok, book, order}`,
  `{:error, :not_found}` or `{:error, :cannot_advance}`.
  """
  @spec advance_order(t(), String.t()) ::
          {:ok, t(), Order.t()} | {:error, atom()}
  def advance_order(%__MODULE__{} = book, id) do
    update_order(book, id, &Order.advance/1)
  end

  @doc """
  Cancels an order. Returns `{:ok, book, order}`,
  `{:error, :not_found}` or `{:error, :cannot_cancel}`.
  """
  @spec cancel_order(t(), String.t()) ::
          {:ok, t(), Order.t()} | {:error, atom()}
  def cancel_order(%__MODULE__{} = book, id) do
    update_order(book, id, &Order.cancel/1)
  end

  defp update_order(book, id, fun) do
    case Map.fetch(book.orders, id) do
      :error ->
        {:error, :not_found}

      {:ok, order} ->
        case fun.(order) do
          {:ok, updated} ->
            {:ok, %{book | orders: Map.put(book.orders, id, updated)}, updated}

          {:error, _} = error ->
            error
        end
    end
  end

  defp fetch_restaurant(catalogue, restaurant_id) do
    case Catalogue.get_restaurant(catalogue, restaurant_id) do
      nil -> {:error, :restaurant_not_found}
      restaurant -> {:ok, restaurant}
    end
  end

  defp check_open(restaurant) do
    if restaurant.open? do
      :ok
    else
      {:error, :restaurant_closed}
    end
  end

  defp resolve_lines(_catalogue, _restaurant_id, []) do
    {:error, :empty_order}
  end

  defp resolve_lines(catalogue, restaurant_id, lines) do
    Enum.reduce_while(lines, {:ok, []}, fn line_attrs, {:ok, acc} ->
      case resolve_line(catalogue, restaurant_id, line_attrs) do
        {:ok, line} -> {:cont, {:ok, acc ++ [line]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp resolve_line(catalogue, restaurant_id, %{item_id: item_id, quantity: quantity}) do
    with {:ok, item} <- fetch_item(catalogue, item_id),
         :ok <- check_item_restaurant(item, restaurant_id),
         :ok <- check_item_available(item),
         {:ok, line} <-
           OrderLine.new(%{
             item_id: item.id,
             name: item.name,
             unit_price_cents: item.price_cents,
             quantity: quantity
           }) do
      {:ok, line}
    end
  end

  defp resolve_line(_catalogue, _restaurant_id, _other) do
    {:error, "each line must have :item_id and :quantity"}
  end

  defp fetch_item(catalogue, item_id) do
    case Catalogue.get_menu_item(catalogue, item_id) do
      nil -> {:error, :item_not_found}
      item -> {:ok, item}
    end
  end

  defp check_item_restaurant(item, restaurant_id) do
    if item.restaurant_id == restaurant_id do
      :ok
    else
      {:error, :item_wrong_restaurant}
    end
  end

  defp check_item_available(item) do
    if item.available? do
      :ok
    else
      {:error, :item_unavailable}
    end
  end
end
