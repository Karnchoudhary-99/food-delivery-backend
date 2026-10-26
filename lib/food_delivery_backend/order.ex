defmodule FoodDeliveryBackend.Order do
  @moduledoc """
  A placed order: the restaurant, snapshot lines, priced totals, and a
  lifecycle status.

  Lifecycle: `:placed` → `:confirmed` → `:preparing` → `:out_for_delivery`
  → `:delivered`. An order can be cancelled from `:placed`, `:confirmed`
  or `:preparing` only — once it is out for delivery it must run to
  completion. Totals are computed at creation and never recomputed, so a
  later menu price change cannot alter a placed order.
  """

  alias FoodDeliveryBackend.OrderLine

  @enforce_keys [:id, :restaurant_id, :lines]
  defstruct [
    :id,
    :restaurant_id,
    :lines,
    status: :placed,
    items_total_cents: 0,
    delivery_fee_cents: 0,
    total_cents: 0
  ]

  @type status ::
          :placed
          | :confirmed
          | :preparing
          | :out_for_delivery
          | :delivered
          | :cancelled

  @type t :: %__MODULE__{
          id: String.t(),
          restaurant_id: String.t(),
          lines: [OrderLine.t()],
          status: status(),
          items_total_cents: non_neg_integer(),
          delivery_fee_cents: non_neg_integer(),
          total_cents: non_neg_integer()
        }

  @next_status %{
    placed: :confirmed,
    confirmed: :preparing,
    preparing: :out_for_delivery,
    out_for_delivery: :delivered
  }

  @cancellable [:placed, :confirmed, :preparing]

  @doc """
  Builds an order from attributes.

  Expects `:restaurant_id`, `:lines` (a non-empty list of `OrderLine`
  structs) and `:delivery_fee_cents`. Returns `{:ok, order}` or
  `{:error, reason}`. When `:min_order_cents` is given, an items total
  below it fails with `:below_minimum_order`.
  """
  @spec new(map()) ::
          {:ok, t()} | {:error, atom() | String.t()}
  def new(attrs) when is_map(attrs) do
    with {:ok, restaurant_id} <- required_string(attrs, :restaurant_id),
         {:ok, lines} <- non_empty_lines(attrs),
         {:ok, fee} <- non_neg_int(attrs, :delivery_fee_cents, 0),
         {:ok, min_order} <- non_neg_int(attrs, :min_order_cents, 0) do
      items_total = Enum.reduce(lines, 0, fn line, acc -> acc + OrderLine.line_total_cents(line) end)

      if items_total < min_order do
        {:error, :below_minimum_order}
      else
        {:ok,
         %__MODULE__{
           id: Map.get(attrs, :id, ""),
           restaurant_id: restaurant_id,
           lines: lines,
           status: :placed,
           items_total_cents: items_total,
           delivery_fee_cents: fee,
           total_cents: items_total + fee
         }}
      end
    end
  end

  @doc """
  Moves an order one step along the lifecycle. Returns
  `{:ok, order}` or `{:error, :cannot_advance}` for terminal orders
  (`:delivered` or `:cancelled`).
  """
  @spec advance(t()) :: {:ok, t()} | {:error, :cannot_advance}
  def advance(%__MODULE__{} = order) do
    case Map.fetch(@next_status, order.status) do
      {:ok, next} -> {:ok, %{order | status: next}}
      :error -> {:error, :cannot_advance}
    end
  end

  @doc """
  Cancels an order. Only `:placed`, `:confirmed` and `:preparing` orders
  can be cancelled; anything further along fails with
  `{:error, :cannot_cancel}`.
  """
  @spec cancel(t()) :: {:ok, t()} | {:error, :cannot_cancel}
  def cancel(%__MODULE__{} = order) do
    if order.status in @cancellable do
      {:ok, %{order | status: :cancelled}}
    else
      {:error, :cannot_cancel}
    end
  end

  @doc "True when the order reached a terminal status."
  @spec terminal?(t()) :: boolean()
  def terminal?(%__MODULE__{} = order) do
    order.status in [:delivered, :cancelled]
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

  defp non_empty_lines(attrs) do
    case Map.get(attrs, :lines) do
      lines when is_list(lines) and lines != [] ->
        if Enum.all?(lines, &match?(%OrderLine{}, &1)) do
          {:ok, lines}
        else
          {:error, ":lines must contain only OrderLine structs"}
        end

      _ ->
        {:error, ":lines must be a non-empty list"}
    end
  end

  defp non_neg_int(attrs, key, default) do
    case Map.get(attrs, key, default) do
      value when is_integer(value) and value >= 0 -> {:ok, value}
      _ -> {:error, "#{key} must be a non-negative integer"}
    end
  end
end
