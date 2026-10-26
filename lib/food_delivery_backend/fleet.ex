defmodule FoodDeliveryBackend.Fleet do
  @moduledoc """
  The in-memory courier fleet.

  Like `Catalogue` and `OrderBook`, a `Fleet` is a plain value: couriers
  and deliveries are kept in maps keyed by id, and ids are handed out from
  counters so they are unique and deterministic within one fleet.
  Assigning a courier to an order creates a delivery and marks the
  courier busy; completing or cancelling the delivery frees them again.
  Nothing is mutated on error.
  """

  alias FoodDeliveryBackend.Courier
  alias FoodDeliveryBackend.Delivery
  alias FoodDeliveryBackend.Order

  defstruct couriers: %{}, deliveries: %{}, next_courier_id: 1, next_delivery_id: 1

  @type t :: %__MODULE__{
          couriers: %{String.t() => Courier.t()},
          deliveries: %{String.t() => Delivery.t()},
          next_courier_id: pos_integer(),
          next_delivery_id: pos_integer()
        }

  @assignable_order_statuses [:preparing, :out_for_delivery]

  @doc "Returns an empty fleet."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Adds a courier to the fleet. Returns `{:ok, fleet, courier}` or
  `{:error, reason}` from `Courier.new/1`. A failed add changes nothing
  — not even the next courier id.
  """
  @spec add_courier(t(), map()) :: {:ok, t(), Courier.t()} | {:error, String.t()}
  def add_courier(%__MODULE__{} = fleet, attrs) when is_map(attrs) do
    case Courier.new(Map.put(attrs, :id, "c#{fleet.next_courier_id}")) do
      {:ok, courier} ->
        updated = %{
          fleet
          | couriers: Map.put(fleet.couriers, courier.id, courier),
            next_courier_id: fleet.next_courier_id + 1
        }

        {:ok, updated, courier}

      {:error, _} = error ->
        error
    end
  end

  @doc "Fetches a courier by id, or `nil`."
  @spec get_courier(t(), String.t()) :: Courier.t() | nil
  def get_courier(%__MODULE__{} = fleet, id), do: Map.get(fleet.couriers, id)

  @doc "Lists all couriers, sorted by id."
  @spec list_couriers(t()) :: [Courier.t()]
  def list_couriers(%__MODULE__{} = fleet) do
    fleet.couriers |> Map.values() |> Enum.sort_by(& &1.id)
  end

  @doc "Lists couriers available for a new delivery, sorted by id."
  @spec available_couriers(t()) :: [Courier.t()]
  def available_couriers(%__MODULE__{} = fleet) do
    fleet |> list_couriers() |> Enum.filter(&Courier.available?/1)
  end

  @doc """
  Assigns a courier to an order, creating its delivery.

  The order must be `:preparing` or `:out_for_delivery` — earlier orders
  are not ready for a courier, and later ones are already finished. The
  courier must exist and be available, and the order must not already
  have an active delivery. Returns `{:ok, fleet, delivery}` or an error:

    * `:courier_not_found` — unknown courier id
    * `:courier_busy` — the courier already has an active delivery
    * `:order_not_assignable` — the order is not preparing/out for delivery
    * `:already_assigned` — the order already has an active delivery
  """
  @spec assign_courier(t(), Order.t(), String.t()) ::
          {:ok, t(), Delivery.t()} | {:error, atom()}
  def assign_courier(%__MODULE__{} = fleet, %Order{} = order, courier_id) do
    with {:ok, courier} <- fetch_courier(fleet, courier_id),
         :ok <- check_order_assignable(order),
         :ok <- check_not_assigned(fleet, order.id),
         :ok <- check_courier_available(courier),
         {:ok, delivery} <-
           Delivery.new(%{
             id: "d#{fleet.next_delivery_id}",
             order_id: order.id,
             courier_id: courier.id
           }) do
      updated = %{
        fleet
        | couriers: Map.put(fleet.couriers, courier.id, %{courier | available?: false}),
          deliveries: Map.put(fleet.deliveries, delivery.id, delivery),
          next_delivery_id: fleet.next_delivery_id + 1
      }

      {:ok, updated, delivery}
    end
  end

  @doc "Fetches a delivery by id, or `nil`."
  @spec get_delivery(t(), String.t()) :: Delivery.t() | nil
  def get_delivery(%__MODULE__{} = fleet, id), do: Map.get(fleet.deliveries, id)

  @doc "Lists all deliveries, sorted by id."
  @spec list_deliveries(t()) :: [Delivery.t()]
  def list_deliveries(%__MODULE__{} = fleet) do
    fleet.deliveries |> Map.values() |> Enum.sort_by(& &1.id)
  end

  @doc "Lists a courier's deliveries, sorted by id."
  @spec deliveries_for_courier(t(), String.t()) :: [Delivery.t()]
  def deliveries_for_courier(%__MODULE__{} = fleet, courier_id) do
    fleet |> list_deliveries() |> Enum.filter(&(&1.courier_id == courier_id))
  end

  @doc "Lists an order's deliveries, sorted by id."
  @spec deliveries_for_order(t(), String.t()) :: [Delivery.t()]
  def deliveries_for_order(%__MODULE__{} = fleet, order_id) do
    fleet |> list_deliveries() |> Enum.filter(&(&1.order_id == order_id))
  end

  @doc """
  Returns an order's in-progress delivery, or `nil`. A delivered or
  cancelled delivery does not block a fresh assignment.
  """
  @spec active_delivery_for_order(t(), String.t()) :: Delivery.t() | nil
  def active_delivery_for_order(%__MODULE__{} = fleet, order_id) do
    fleet
    |> deliveries_for_order(order_id)
    |> Enum.find(&(&1.status in [:assigned, :picked_up, :in_transit]))
  end

  @doc """
  Advances a delivery one lifecycle step. When the delivery reaches
  `:delivered`, its courier becomes available again. Returns
  `{:ok, fleet, delivery}`, `{:error, :not_found}` or
  `{:error, :cannot_advance}`.
  """
  @spec advance_delivery(t(), String.t()) ::
          {:ok, t(), Delivery.t()} | {:error, atom()}
  def advance_delivery(%__MODULE__{} = fleet, id) do
    update_delivery(fleet, id, &Delivery.advance/1)
  end

  @doc """
  Records a courier's current location on a delivery. Returns
  `{:ok, fleet, delivery}`, `{:error, :not_found}` or the error from
  `Delivery.update_location/2`.
  """
  @spec update_delivery_location(t(), String.t(), String.t()) ::
          {:ok, t(), Delivery.t()} | {:error, atom() | String.t()}
  def update_delivery_location(%__MODULE__{} = fleet, id, location) do
    update_delivery(fleet, id, &Delivery.update_location(&1, location))
  end

  @doc """
  Cancels a delivery and frees its courier. Returns
  `{:ok, fleet, delivery}`, `{:error, :not_found}` or
  `{:error, :cannot_cancel}`.
  """
  @spec cancel_delivery(t(), String.t()) ::
          {:ok, t(), Delivery.t()} | {:error, atom()}
  def cancel_delivery(%__MODULE__{} = fleet, id) do
    update_delivery(fleet, id, &Delivery.cancel/1)
  end

  defp update_delivery(fleet, id, fun) do
    case Map.fetch(fleet.deliveries, id) do
      :error ->
        {:error, :not_found}

      {:ok, delivery} ->
        case fun.(delivery) do
          {:ok, updated} ->
            fleet = %{fleet | deliveries: Map.put(fleet.deliveries, id, updated)}

            fleet =
              if updated.status in [:delivered, :cancelled] do
                free_courier(fleet, updated.courier_id)
              else
                fleet
              end

            {:ok, fleet, updated}

          {:error, _} = error ->
            error
        end
    end
  end

  defp free_courier(fleet, courier_id) do
    case Map.fetch(fleet.couriers, courier_id) do
      :error ->
        fleet

      {:ok, courier} ->
        %{fleet | couriers: Map.put(fleet.couriers, courier_id, %{courier | available?: true})}
    end
  end

  defp fetch_courier(fleet, courier_id) do
    case Map.fetch(fleet.couriers, courier_id) do
      :error -> {:error, :courier_not_found}
      {:ok, courier} -> {:ok, courier}
    end
  end

  defp check_order_assignable(order) do
    if order.status in @assignable_order_statuses do
      :ok
    else
      {:error, :order_not_assignable}
    end
  end

  defp check_not_assigned(fleet, order_id) do
    if active_delivery_for_order(fleet, order_id) == nil do
      :ok
    else
      {:error, :already_assigned}
    end
  end

  defp check_courier_available(courier) do
    if Courier.available?(courier) do
      :ok
    else
      {:error, :courier_busy}
    end
  end
end
