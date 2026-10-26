defmodule FoodDeliveryBackend.CatalogueTest do
  use ExUnit.Case, async: true

  alias FoodDeliveryBackend.Catalogue

  setup do
    {:ok, catalogue, restaurant} =
      Catalogue.new() |> Catalogue.add_restaurant(%{name: "Dosa House", cuisine: "South Indian"})

    {:ok, catalogue: catalogue, restaurant: restaurant}
  end

  test "add_restaurant assigns sequential ids and get/list work", %{catalogue: catalogue} do
    assert [%{id: "r1", name: "Dosa House"}] = Catalogue.list_restaurants(catalogue)
    assert Catalogue.get_restaurant(catalogue, "r1").cuisine == "South Indian"
    assert Catalogue.get_restaurant(catalogue, "r9") == nil

    {:ok, catalogue, second} =
      Catalogue.add_restaurant(catalogue, %{name: "Burger Joint", cuisine: "American"})

    assert second.id == "r2"
    assert length(Catalogue.list_restaurants(catalogue)) == 2
  end

  test "add_restaurant rejects invalid data without changing the catalogue",
       %{catalogue: catalogue} do
    assert {:error, _} = Catalogue.add_restaurant(catalogue, %{name: "", cuisine: "X"})
    assert length(Catalogue.list_restaurants(catalogue)) == 1
  end

  test "update_restaurant and remove_restaurant", %{catalogue: catalogue} do
    {:ok, catalogue, updated} =
      Catalogue.update_restaurant(catalogue, "r1", %{open?: false})

    assert updated.open? == false
    assert {:error, :not_found} = Catalogue.update_restaurant(catalogue, "r9", %{})
    assert {:error, _} = Catalogue.update_restaurant(catalogue, "r1", %{name: ""})

    {:ok, catalogue} = Catalogue.remove_restaurant(catalogue, "r1")
    assert Catalogue.list_restaurants(catalogue) == []
    assert {:ok, _} = Catalogue.remove_restaurant(catalogue, "r1")
  end

  test "items are scoped to their restaurant", %{catalogue: catalogue, restaurant: restaurant} do
    {:ok, catalogue, dosa} =
      Catalogue.add_menu_item(catalogue, restaurant.id, %{name: "Masala Dosa", price_cents: 120})

    {:ok, catalogue, coffee} =
      Catalogue.add_menu_item(catalogue, restaurant.id, %{
        name: "Filter Coffee",
        price_cents: 40,
        category: "drink"
      })

    assert [^dosa, ^coffee] = Catalogue.list_menu_items(catalogue, restaurant.id)
    assert Catalogue.list_menu_items(catalogue, "r9") == []
    assert Catalogue.get_menu_item(catalogue, dosa.id).price_cents == 120

    assert {:error, :restaurant_not_found} =
             Catalogue.add_menu_item(catalogue, "r9", %{name: "X", price_cents: 10})
  end

  test "availability filtering and toggling", %{catalogue: catalogue, restaurant: restaurant} do
    {:ok, catalogue, dosa} =
      Catalogue.add_menu_item(catalogue, restaurant.id, %{name: "Masala Dosa", price_cents: 120})

    {:ok, catalogue, _coffee} =
      Catalogue.add_menu_item(catalogue, restaurant.id, %{
        name: "Filter Coffee",
        price_cents: 40,
        available?: false
      })

    assert [^dosa] = Catalogue.available_menu_items(catalogue, restaurant.id)

    {:ok, catalogue, sold_out} =
      Catalogue.set_item_availability(catalogue, dosa.id, false)

    assert sold_out.available? == false
    assert Catalogue.available_menu_items(catalogue, restaurant.id) == []
    assert {:error, :not_found} = Catalogue.set_item_availability(catalogue, "m9", true)
  end

  test "update and remove menu items", %{catalogue: catalogue, restaurant: restaurant} do
    {:ok, catalogue, dosa} =
      Catalogue.add_menu_item(catalogue, restaurant.id, %{name: "Masala Dosa", price_cents: 120})

    {:ok, catalogue, updated} =
      Catalogue.update_menu_item(catalogue, dosa.id, %{price_cents: 150})

    assert updated.price_cents == 150
    assert {:error, :not_found} = Catalogue.update_menu_item(catalogue, "m9", %{})
    assert {:error, _} = Catalogue.update_menu_item(catalogue, dosa.id, %{price_cents: 0})

    {:ok, catalogue} = Catalogue.remove_menu_item(catalogue, dosa.id)
    assert Catalogue.list_menu_items(catalogue, restaurant.id) == []
  end

  test "removing a restaurant removes its items", %{catalogue: catalogue, restaurant: restaurant} do
    {:ok, catalogue, _item} =
      Catalogue.add_menu_item(catalogue, restaurant.id, %{name: "Masala Dosa", price_cents: 120})

    {:ok, catalogue} = Catalogue.remove_restaurant(catalogue, restaurant.id)
    assert Catalogue.list_menu_items(catalogue, restaurant.id) == []
  end

  test "search matches name and cuisine case-insensitively", %{catalogue: catalogue} do
    {:ok, catalogue, _} =
      Catalogue.add_restaurant(catalogue, %{name: "Burger Joint", cuisine: "American"})

    {:ok, catalogue, _} =
      Catalogue.add_restaurant(catalogue, %{
        name: "Sushi Bar",
        cuisine: "Japanese",
        open?: false
      })

    assert [%{name: "Dosa House"}] = Catalogue.search_restaurants(catalogue, "dosa")
    assert [%{name: "Sushi Bar"}] = Catalogue.search_restaurants(catalogue, "JAPANESE")

    assert [%{name: "Burger Joint"}] =
             Catalogue.search_restaurants(catalogue, "", cuisine: "american")

    assert [%{name: "Dosa House"}, %{name: "Burger Joint"}] =
             Catalogue.search_restaurants(catalogue, "", open_only: true)

    assert [] = Catalogue.search_restaurants(catalogue, "pizza")
  end
end
