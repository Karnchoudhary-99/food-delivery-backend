defmodule FoodDeliveryBackend.MenuItemTest do
  use ExUnit.Case, async: true

  alias FoodDeliveryBackend.MenuItem

  test "new/1 builds an item with defaults" do
    assert {:ok, item} =
             MenuItem.new(%{restaurant_id: "r1", name: "Masala Dosa", price_cents: 120})

    assert item.description == ""
    assert item.category == "main"
    assert item.available? == true
  end

  test "new/1 honours description, category and availability" do
    assert {:ok, item} =
             MenuItem.new(%{
               restaurant_id: "r1",
               name: "Cola",
               price_cents: 60,
               description: "Chilled",
               category: "drink",
               available?: false
             })

    assert item.description == "Chilled"
    assert item.category == "drink"
    assert item.available? == false
  end

  test "new/1 rejects bad name, restaurant id and price" do
    assert {:error, _} = MenuItem.new(%{restaurant_id: "r1", name: "", price_cents: 100})
    assert {:error, _} = MenuItem.new(%{name: "Dosa", price_cents: 100})
    assert {:error, _} = MenuItem.new(%{restaurant_id: "r1", name: "Dosa", price_cents: 0})
    assert {:error, _} = MenuItem.new(%{restaurant_id: "r1", name: "Dosa", price_cents: -5})
    assert {:error, _} = MenuItem.new(%{restaurant_id: "r1", name: "Dosa", price_cents: 12.5})
    assert {:error, _} = MenuItem.new(%{restaurant_id: "r1", name: "Dosa"})
  end

  test "update/2 applies changes, re-validates and keeps id and restaurant" do
    {:ok, item} =
      MenuItem.new(%{id: "m1", restaurant_id: "r1", name: "Dosa", price_cents: 120})

    assert {:ok, updated} = MenuItem.update(item, %{price_cents: 150, available?: false})
    assert updated.price_cents == 150
    assert updated.available? == false
    assert {:error, _} = MenuItem.update(item, %{price_cents: 0})

    assert {:ok, kept} =
             MenuItem.update(item, %{id: "m9", restaurant_id: "r9", name: "Idli"})

    assert kept.id == "m1"
    assert kept.restaurant_id == "r1"
    assert kept.name == "Idli"
  end
end
