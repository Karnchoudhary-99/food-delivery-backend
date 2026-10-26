defmodule FoodDeliveryBackend.Delivery do
  @moduledoc """
  A courier's delivery of one order, with a tracking history.

  Lifecycle: `:assigned` → `:picked_up` → `:in_transit` → `:delivered`.
  A delivery can be cancelled from `:assigned` or `:picked_up` only — once
  it is in transit the order is out for delivery and must run to
  completion. Every status change and location update appends an event to
  `history`, so the full tracking timeline is readable from the struct
  itself. Event sequence numbers are per-delivery counters, not wall-clock
  times, which keeps the history deterministic and easy to test.
  """

  @enforce_keys [:id, :order_id, :courier_id]
  defstruct [:id, :order_id, :courier_id, status: :assigned, location: nil, history: []]

  @type status :: :assigned | :picked_up | :in_transit | :delivered | :cancelled

  @type event :: %{seq: pos_integer(), status: status(), location: String.t() | nil}

  @type t :: %__MODULE__{
          id: String.t(),
          order_id: String.t(),
          courier_id: String.t(),
          status: status(),
          location: String.t() | nil,
          history: [event()]
        }

  @next_status %{
    assigned: :picked_up,
    picked_up: :in_transit,
    in_transit: :delivered
  }

  @cancellable [:assigned, :picked_up]

  @doc """
  Builds a delivery from attributes.

  Expects `:order_id` and `:courier_id` (non-blank strings). The initial
  history holds one `:assigned` event, so a fresh delivery already has a
  tracking timeline.
  """
  @spec new(map()) :: {:ok, t()} | {:error, String.t()}
  def new(attrs) when is_map(attrs) do
    with {:ok, order_id} <- required_string(attrs, :order_id),
         {:ok, courier_id} <- required_string(attrs, :courier_id) do
      delivery = %__MODULE__{
        id: Map.get(attrs, :id, ""),
        order_id: order_id,
        courier_id: courier_id
      }

      {:ok, record_event(delivery, :assigned)}
    end
  end

  @doc """
  Moves a delivery one step along the lifecycle. Returns
  `{:ok, delivery}` or `{:error, :cannot_advance}` for terminal
  deliveries (`:delivered` or `:cancelled`).
  """
  @spec advance(t()) :: {:ok, t()} | {:error, :cannot_advance}
  def advance(%__MODULE__{} = delivery) do
    case Map.fetch(@next_status, delivery.status) do
      {:ok, next} -> {:ok, record_event(%{delivery | status: next}, next)}
      :error -> {:error, :cannot_advance}
    end
  end

  @doc """
  Records the courier's current location (a non-blank string) without
  changing the status. Returns `{:ok, delivery}` or an error:
  `{:error, :delivery_finished}` for terminal deliveries, or a string
  for an invalid location. The location is visible on the delivery and
  in the latest history event.
  """
  @spec update_location(t(), String.t()) ::
          {:ok, t()} | {:error, :delivery_finished | String.t()}
  def update_location(%__MODULE__{} = delivery, location) when is_binary(location) do
    cond do
      terminal?(delivery) ->
        {:error, :delivery_finished}

      String.trim(location) == "" ->
        {:error, "location must not be blank"}

      true ->
        {:ok, record_event(%{delivery | location: location}, delivery.status)}
    end
  end

  def update_location(%__MODULE__{}, _location) do
    {:error, "location must be a string"}
  end

  @doc """
  Cancels a delivery. Only `:assigned` and `:picked_up` deliveries can
  be cancelled; anything further along fails with
  `{:error, :cannot_cancel}`.
  """
  @spec cancel(t()) :: {:ok, t()} | {:error, :cannot_cancel}
  def cancel(%__MODULE__{} = delivery) do
    if delivery.status in @cancellable do
      {:ok, record_event(%{delivery | status: :cancelled}, :cancelled)}
    else
      {:error, :cannot_cancel}
    end
  end

  @doc "True when the delivery reached a terminal status."
  @spec terminal?(t()) :: boolean()
  def terminal?(%__MODULE__{} = delivery) do
    delivery.status in [:delivered, :cancelled]
  end

  defp record_event(%__MODULE__{} = delivery, status) do
    event = %{seq: length(delivery.history) + 1, status: status, location: delivery.location}
    %{delivery | history: delivery.history ++ [event]}
  end

  defp required_string(attrs, key) do
    case Map.get(attrs, key) do
      value when is_binary(value) ->
        if String.trim(value) == "" do
          {:error, "#{key} must not be blank"}
        else
          {:ok, value}
        end

      _ ->
        {:error, "#{key} is required and must be a string"}
    end
  end
end
