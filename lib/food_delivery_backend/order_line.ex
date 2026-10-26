defmodule FoodDeliveryBackend.OrderLine do
  @moduledoc """
  One line of an order: a dish, how many of it, and the price at order time.

  The name and unit price are snapshots taken from the menu when the order
  is placed, so later menu edits never rewrite what a customer was charged.
  Validation lives in `new/1` so invalid lines can never enter an `Order`.
  """

  @enforce_keys [:item_id, :name, :unit_price_cents, :quantity]
  defstruct [:item_id, :name, :unit_price_cents, :quantity]

  @type t :: %__MODULE__{
          item_id: String.t(),
          name: String.t(),
          unit_price_cents: pos_integer(),
          quantity: pos_integer()
        }

  @doc """
  Builds an order line from attributes.

  Returns `{:ok, line}` or `{:error, reason}`. `:item_id` and `:name`
  must be non-blank strings; `:unit_price_cents` and `:quantity` must be
  positive integers.
  """
  @spec new(map()) :: {:ok, t()} | {:error, String.t()}
  def new(attrs) when is_map(attrs) do
    with {:ok, item_id} <- required_string(attrs, :item_id),
         {:ok, name} <- required_string(attrs, :name),
         {:ok, price} <- positive_int(attrs, :unit_price_cents),
         {:ok, quantity} <- positive_int(attrs, :quantity) do
      {:ok,
       %__MODULE__{
         item_id: item_id,
         name: name,
         unit_price_cents: price,
         quantity: quantity
       }}
    end
  end

  @doc "Line total in cents: unit price times quantity."
  @spec line_total_cents(t()) :: pos_integer()
  def line_total_cents(%__MODULE__{} = line) do
    line.unit_price_cents * line.quantity
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

  defp positive_int(attrs, key) do
    case Map.get(attrs, key) do
      value when is_integer(value) and value > 0 -> {:ok, value}
      _ -> {:error, "#{key} must be a positive integer"}
    end
  end
end
