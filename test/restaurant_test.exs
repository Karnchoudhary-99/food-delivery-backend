defmodule FoodDeliveryBackend.RestaurantTest do
  use ExUnit.Case, async: true

  alias FoodDeliveryBackend.Restaurant

  test "new/1 builds a restaurant with defaults" do
    assert {:ok, restaurant} = Restaurant.new(%{name: "Dosa House", cuisine: "South Indian"})
    assert restaurant.name == "Dosa House"
    assert restaurant.delivery_fee_cents == 0
    assert restaurant.min_order_cents == 0
    assert restaurant.open? == true
  end

  test "new/1 honours explicit fee, minimum order and open flag" do
    assert {:ok, restaurant} =
             Restaurant.new(%{
               name: "Sushi Bar",
               cuisine: "Japanese",
               delivery_fee_cents: 300,
               min_order_cents: 1200,
               open?: false
             })

    assert restaurant.delivery_fee_cents == 300
    assert restaurant.min_order_cents == 1200
    assert restaurant.open? == false
  end

  test "new/1 rejects blank or missing name and cuisine" do
    assert {:error, _} = Restaurant.new(%{name: "  ", cuisine: "Indian"})
    assert {:error, _} = Restaurant.new(%{cuisine: "Indian"})
    assert {:error, _} = Restaurant.new(%{name: "Dosa House"})
    assert {:error, _} = Restaurant.new(%{name: "Dosa House", cuisine: 42})
  end

  test "new/1 rejects negative fees and non-boolean open flag" do
    assert {:error, _} =
             Restaurant.new(%{name: "A", cuisine: "B", delivery_fee_cents: -1})

    assert {:error, _} =
             Restaurant.new(%{name: "A", cuisine: "B", min_order_cents: -50})

    assert {:error, _} = Restaurant.new(%{name: "A", cuisine: "B", open?: "yes"})
  end

  test "update/2 applies changes and re-validates" do
    {:ok, restaurant} = Restaurant.new(%{name: "Dosa House", cuisine: "South Indian"})
    assert {:ok, updated} = Restaurant.update(restaurant, %{open?: false, delivery_fee_cents: 99})
    assert updated.open? == false
    assert updated.delivery_fee_cents == 99
    assert updated.name == "Dosa House"
    assert {:error, _} = Restaurant.update(restaurant, %{name: ""})
  end

  test "update/2 cannot change the id" do
    {:ok, restaurant} = Restaurant.new(%{id: "r1", name: "A", cuisine: "B"})
    assert {:ok, updated} = Restaurant.update(restaurant, %{id: "r9", name: "C"})
    assert updated.id == "r1"
    assert updated.name == "C"
  end
end
