defmodule FoodDeliveryBackend.Restaurant do
  @moduledoc """
  A restaurant listed in the catalogue.

  A restaurant has a name, a cuisine, an optional delivery fee and minimum
  order (both in cents), and an open flag. Validation lives in `new/1` so
  invalid restaurants can never enter a `Catalogue`.
  """

  @enforce_keys [:id, :name, :cuisine]
  defstruct [
    :id,
    :name,
    :cuisine,
    delivery_fee_cents: 0,
    min_order_cents: 0,
    open?: true
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          cuisine: String.t(),
          delivery_fee_cents: non_neg_integer(),
          min_order_cents: non_neg_integer(),
          open?: boolean()
        }

  @doc """
  Builds a restaurant from attributes.

  Returns `{:ok, restaurant}` or `{:error, reason}`. `:name` and `:cuisine`
  must be non-blank strings; `:delivery_fee_cents` and `:min_order_cents`,
  when given, must be non-negative integers.
  """
  @spec new(map()) :: {:ok, t()} | {:error, String.t()}
  def new(attrs) when is_map(attrs) do
    with {:ok, name} <- required_string(attrs, :name),
         {:ok, cuisine} <- required_string(attrs, :cuisine),
         {:ok, fee} <- optional_non_neg_int(attrs, :delivery_fee_cents, 0),
         {:ok, min_order} <- optional_non_neg_int(attrs, :min_order_cents, 0),
         {:ok, open?} <- optional_boolean(attrs, :open?, true) do
      {:ok,
       %__MODULE__{
         id: Map.get(attrs, :id, ""),
         name: name,
         cuisine: cuisine,
         delivery_fee_cents: fee,
         min_order_cents: min_order,
         open?: open?
       }}
    end
  end

  @doc """
  Applies attribute updates to a restaurant, re-validating the result.
  """
  @spec update(t(), map()) :: {:ok, t()} | {:error, String.t()}
  def update(%__MODULE__{} = restaurant, attrs) when is_map(attrs) do
    merged =
      restaurant
      |> Map.from_struct()
      |> Map.merge(attrs)
      |> Map.put(:id, restaurant.id)

    new(merged)
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

  defp optional_non_neg_int(attrs, key, default) do
    case Map.get(attrs, key, default) do
      value when is_integer(value) and value >= 0 -> {:ok, value}
      _ -> {:error, "#{key} must be a non-negative integer"}
    end
  end

  defp optional_boolean(attrs, key, default) do
    case Map.get(attrs, key, default) do
      value when is_boolean(value) -> {:ok, value}
      _ -> {:error, "#{key} must be a boolean"}
    end
  end
end
