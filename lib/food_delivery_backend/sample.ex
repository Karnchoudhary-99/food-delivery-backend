defmodule FoodDeliveryBackend.Sample do
  @moduledoc """
  A small demo catalogue: three restaurants with a handful of dishes each,
  so the catalogue API can be explored without building data by hand.
  """

  alias FoodDeliveryBackend.Catalogue

  @doc "Returns a catalogue pre-filled with demo restaurants and menus."
  @spec catalogue() :: Catalogue.t()
  def catalogue do
    {:ok, catalogue, dosa_house} =
      Catalogue.new()
      |> add_restaurant("Dosa House", "South Indian",
        delivery_fee_cents: 150,
        min_order_cents: 500
      )

    {:ok, catalogue, burger_joint} =
      add_restaurant(catalogue, "Burger Joint", "American",
        delivery_fee_cents: 200,
        min_order_cents: 800
      )

    {:ok, catalogue, sushi_bar} =
      add_restaurant(catalogue, "Sushi Bar", "Japanese",
        delivery_fee_cents: 300,
        min_order_cents: 1200,
        open?: false
      )

    catalogue
    |> add_items(dosa_house, [
      {"Masala Dosa", 120, "main"},
      {"Idli Sambar", 80, "main"},
      {"Filter Coffee", 40, "drink"}
    ])
    |> add_items(burger_joint, [
      {"Classic Burger", 250, "main"},
      {"Cheese Fries", 150, "side"},
      {"Cola", 60, "drink"}
    ])
    |> add_items(sushi_bar, [
      {"Salmon Nigiri", 400, "main"},
      {"Miso Soup", 120, "starter"}
    ])
  end

  defp add_restaurant(catalogue, name, cuisine, opts) do
    Catalogue.add_restaurant(
      catalogue,
      %{name: name, cuisine: cuisine} |> Map.merge(Map.new(opts))
    )
  end

  defp add_items(catalogue, restaurant, items) do
    Enum.reduce(items, catalogue, fn {name, price, category}, acc ->
      {:ok, updated, _item} =
        Catalogue.add_menu_item(acc, restaurant.id, %{
          name: name,
          price_cents: price,
          category: category
        })

      updated
    end)
  end
end
