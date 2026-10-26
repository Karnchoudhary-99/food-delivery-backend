defmodule FoodDeliveryBackend.Catalogue do
  @moduledoc """
  The in-memory restaurant + menu catalogue.

  A `Catalogue` is a plain value (no process): restaurants and menu items are
  kept in maps keyed by id, and ids are handed out from counters on the
  struct so ids are unique and deterministic within one catalogue. Every
  mutating function returns an updated catalogue, which keeps the module easy
  to test and to wrap in a GenServer later.
  """

  alias FoodDeliveryBackend.MenuItem
  alias FoodDeliveryBackend.Restaurant

  defstruct restaurants: %{},
            items: %{},
            next_restaurant_id: 1,
            next_item_id: 1

  @type t :: %__MODULE__{
          restaurants: %{String.t() => Restaurant.t()},
          items: %{String.t() => MenuItem.t()},
          next_restaurant_id: pos_integer(),
          next_item_id: pos_integer()
        }

  @doc "Returns an empty catalogue."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  # -- restaurants -------------------------------------------------------

  @doc """
  Adds a restaurant. Returns `{:ok, catalogue, restaurant}` or
  `{:error, reason}`; the catalogue is unchanged on error.
  """
  @spec add_restaurant(t(), map()) ::
          {:ok, t(), Restaurant.t()} | {:error, String.t()}
  def add_restaurant(%__MODULE__{} = catalogue, attrs) when is_map(attrs) do
    id = "r#{catalogue.next_restaurant_id}"

    case Restaurant.new(Map.put(attrs, :id, id)) do
      {:ok, restaurant} ->
        updated = %{
          catalogue
          | restaurants: Map.put(catalogue.restaurants, id, restaurant),
            next_restaurant_id: catalogue.next_restaurant_id + 1
        }

        {:ok, updated, restaurant}

      {:error, _} = error ->
        error
    end
  end

  @doc "Fetches a restaurant by id, or `nil`."
  @spec get_restaurant(t(), String.t()) :: Restaurant.t() | nil
  def get_restaurant(%__MODULE__{} = catalogue, id) do
    Map.get(catalogue.restaurants, id)
  end

  @doc "Lists all restaurants, sorted by id."
  @spec list_restaurants(t()) :: [Restaurant.t()]
  def list_restaurants(%__MODULE__{} = catalogue) do
    catalogue.restaurants |> Map.values() |> Enum.sort_by(& &1.id)
  end

  @doc """
  Updates a restaurant. Returns `{:ok, catalogue, restaurant}`,
  `{:error, :not_found}` or `{:error, reason}`.
  """
  @spec update_restaurant(t(), String.t(), map()) ::
          {:ok, t(), Restaurant.t()} | {:error, atom() | String.t()}
  def update_restaurant(%__MODULE__{} = catalogue, id, attrs) do
    case Map.fetch(catalogue.restaurants, id) do
      :error ->
        {:error, :not_found}

      {:ok, restaurant} ->
        case Restaurant.update(restaurant, attrs) do
          {:ok, updated} ->
            updated_catalogue = %{
              catalogue
              | restaurants: Map.put(catalogue.restaurants, id, updated)
            }

            {:ok, updated_catalogue, updated}

          {:error, _} = error ->
            error
        end
    end
  end

  @doc """
  Removes a restaurant and all of its menu items. Removing an unknown id
  is a no-op that still returns `{:ok, catalogue}`.
  """
  @spec remove_restaurant(t(), String.t()) :: {:ok, t()}
  def remove_restaurant(%__MODULE__{} = catalogue, id) do
    items = catalogue.items |> Map.reject(fn {_item_id, item} -> item.restaurant_id == id end)

    {:ok, %{catalogue | restaurants: Map.delete(catalogue.restaurants, id), items: items}}
  end

  # -- menu items --------------------------------------------------------

  @doc """
  Adds a menu item to a restaurant. Returns `{:ok, catalogue, item}`,
  `{:error, :restaurant_not_found}` or `{:error, reason}`.
  """
  @spec add_menu_item(t(), String.t(), map()) ::
          {:ok, t(), MenuItem.t()} | {:error, atom() | String.t()}
  def add_menu_item(%__MODULE__{} = catalogue, restaurant_id, attrs)
      when is_map(attrs) do
    if Map.has_key?(catalogue.restaurants, restaurant_id) do
      id = "m#{catalogue.next_item_id}"
      attrs = attrs |> Map.put(:id, id) |> Map.put(:restaurant_id, restaurant_id)

      case MenuItem.new(attrs) do
        {:ok, item} ->
          updated = %{
            catalogue
            | items: Map.put(catalogue.items, id, item),
              next_item_id: catalogue.next_item_id + 1
          }

          {:ok, updated, item}

        {:error, _} = error ->
          error
      end
    else
      {:error, :restaurant_not_found}
    end
  end

  @doc "Fetches a menu item by id, or `nil`."
  @spec get_menu_item(t(), String.t()) :: MenuItem.t() | nil
  def get_menu_item(%__MODULE__{} = catalogue, id) do
    Map.get(catalogue.items, id)
  end

  @doc "Lists a restaurant's menu items, sorted by id."
  @spec list_menu_items(t(), String.t()) :: [MenuItem.t()]
  def list_menu_items(%__MODULE__{} = catalogue, restaurant_id) do
    catalogue.items
    |> Map.values()
    |> Enum.filter(&(&1.restaurant_id == restaurant_id))
    |> Enum.sort_by(& &1.id)
  end

  @doc "Lists only the available items on a restaurant's menu."
  @spec available_menu_items(t(), String.t()) :: [MenuItem.t()]
  def available_menu_items(%__MODULE__{} = catalogue, restaurant_id) do
    catalogue |> list_menu_items(restaurant_id) |> Enum.filter(& &1.available?)
  end

  @doc """
  Updates a menu item. Returns `{:ok, catalogue, item}`,
  `{:error, :not_found}` or `{:error, reason}`.
  """
  @spec update_menu_item(t(), String.t(), map()) ::
          {:ok, t(), MenuItem.t()} | {:error, atom() | String.t()}
  def update_menu_item(%__MODULE__{} = catalogue, id, attrs) do
    case Map.fetch(catalogue.items, id) do
      :error ->
        {:error, :not_found}

      {:ok, item} ->
        case MenuItem.update(item, attrs) do
          {:ok, updated} ->
            {:ok, %{catalogue | items: Map.put(catalogue.items, id, updated)}, updated}

          {:error, _} = error ->
            error
        end
    end
  end

  @doc """
  Marks a menu item available or unavailable. Returns `{:ok, catalogue, item}`
  or `{:error, :not_found}`.
  """
  @spec set_item_availability(t(), String.t(), boolean()) ::
          {:ok, t(), MenuItem.t()} | {:error, :not_found}
  def set_item_availability(%__MODULE__{} = catalogue, id, available?)
      when is_boolean(available?) do
    update_menu_item(catalogue, id, %{available?: available?})
  end

  @doc "Removes a menu item. Removing an unknown id is a no-op."
  @spec remove_menu_item(t(), String.t()) :: {:ok, t()}
  def remove_menu_item(%__MODULE__{} = catalogue, id) do
    {:ok, %{catalogue | items: Map.delete(catalogue.items, id)}}
  end

  # -- search ------------------------------------------------------------

  @doc """
  Searches restaurants by name or cuisine (case-insensitive substring).

  Options:
    * `:cuisine` — exact cuisine match (case-insensitive)
    * `:open_only` — when `true`, only restaurants currently open
  """
  @spec search_restaurants(t(), String.t(), keyword()) :: [Restaurant.t()]
  def search_restaurants(%__MODULE__{} = catalogue, query, opts \\ []) do
    needle = query |> to_string() |> String.downcase()
    cuisine = opts |> Keyword.get(:cuisine) |> downcase_or_nil()
    open_only? = Keyword.get(opts, :open_only, false)

    catalogue
    |> list_restaurants()
    |> Enum.filter(fn restaurant ->
      matches_query?(restaurant, needle) and
        matches_cuisine?(restaurant, cuisine) and
        (not open_only? or restaurant.open?)
    end)
  end

  defp matches_query?(_restaurant, ""), do: true

  defp matches_query?(restaurant, needle) do
    String.contains?(String.downcase(restaurant.name), needle) or
      String.contains?(String.downcase(restaurant.cuisine), needle)
  end

  defp matches_cuisine?(_restaurant, nil), do: true

  defp matches_cuisine?(restaurant, cuisine) do
    String.downcase(restaurant.cuisine) == cuisine
  end

  defp downcase_or_nil(nil), do: nil
  defp downcase_or_nil(value), do: value |> to_string() |> String.downcase()
end
