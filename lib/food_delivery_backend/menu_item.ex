defmodule FoodDeliveryBackend.MenuItem do
  @moduledoc """
  One dish on a restaurant's menu.

  Prices are integer cents to avoid float rounding in order totals. An item
  belongs to exactly one restaurant and can be marked unavailable (e.g. sold
  out) without being deleted, so past orders still reference a real dish.
  """

  @enforce_keys [:id, :restaurant_id, :name, :price_cents]
  defstruct [
    :id,
    :restaurant_id,
    :name,
    :price_cents,
    description: "",
    category: "main",
    available?: true
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          restaurant_id: String.t(),
          name: String.t(),
          price_cents: pos_integer(),
          description: String.t(),
          category: String.t(),
          available?: boolean()
        }

  @doc """
  Builds a menu item from attributes.

  Returns `{:ok, item}` or `{:error, reason}`. `:restaurant_id` and `:name`
  must be non-blank strings and `:price_cents` a positive integer.
  """
  @spec new(map()) :: {:ok, t()} | {:error, String.t()}
  def new(attrs) when is_map(attrs) do
    with {:ok, restaurant_id} <- required_string(attrs, :restaurant_id),
         {:ok, name} <- required_string(attrs, :name),
         {:ok, price} <- positive_price(attrs),
         {:ok, description} <- optional_string(attrs, :description, ""),
         {:ok, category} <- optional_string(attrs, :category, "main"),
         {:ok, available?} <- optional_boolean(attrs, :available?, true) do
      {:ok,
       %__MODULE__{
         id: Map.get(attrs, :id, ""),
         restaurant_id: restaurant_id,
         name: name,
         price_cents: price,
         description: description,
         category: category,
         available?: available?
       }}
    end
  end

  @doc """
  Applies attribute updates to a menu item, re-validating the result.
  """
  @spec update(t(), map()) :: {:ok, t()} | {:error, String.t()}
  def update(%__MODULE__{} = item, attrs) when is_map(attrs) do
    merged =
      item
      |> Map.from_struct()
      |> Map.merge(attrs)
      |> Map.put(:id, item.id)
      |> Map.put(:restaurant_id, item.restaurant_id)

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

  defp positive_price(attrs) do
    case Map.get(attrs, :price_cents) do
      value when is_integer(value) and value > 0 -> {:ok, value}
      _ -> {:error, "price_cents must be a positive integer"}
    end
  end

  defp optional_string(attrs, key, default) do
    case Map.get(attrs, key, default) do
      value when is_binary(value) -> {:ok, value}
      _ -> {:error, "#{key} must be a string"}
    end
  end

  defp optional_boolean(attrs, key, default) do
    case Map.get(attrs, key, default) do
      value when is_boolean(value) -> {:ok, value}
      _ -> {:error, "#{key} must be a boolean"}
    end
  end
end
