defmodule FoodDeliveryBackend.OrderBookTest do
  use ExUnit.Case, async: true

  alias FoodDeliveryBackend.Catalogue
  alias FoodDeliveryBackend.OrderBook
  alias FoodDeliveryBackend.Sample

  defp item_id(catalogue, name) do
    catalogue
    |> Catalogue.list_restaurants()
    |> Enum.flat_map(&Catalogue.list_menu_items(catalogue, &1.id))
    |> Enum.find(&(&1.name == name))
    |> Map.fetch!(:id)
  end

  defp restaurant_id(catalogue, name) do
    catalogue
    |> Catalogue.list_restaurants()
    |> Enum.find(&(&1.name == name))
    |> Map.fetch!(:id)
  end

  setup do
    catalogue = Sample.catalogue()
    %{catalogue: catalogue, dosa: restaurant_id(catalogue, "Dosa House")}
  end

  test "place_order/4 prices the order from the menu and the delivery fee", %{
    catalogue: catalogue,
    dosa: dosa
  } do
    dosa_id = item_id(catalogue, "Masala Dosa")

    assert {:ok, _book, order} =
             OrderBook.new()
             |> OrderBook.place_order(catalogue, dosa, [%{item_id: dosa_id, quantity: 5}])

    assert order.id == "o1"
    assert order.status == :placed
    assert order.items_total_cents == 600
    assert order.delivery_fee_cents == 150
    assert order.total_cents == 750
    assert hd(order.lines).name == "Masala Dosa"
    assert hd(order.lines).unit_price_cents == 120
  end

  test "place_order/4 hands out sequential ids and a failed order consumes none", %{
    catalogue: catalogue,
    dosa: dosa
  } do
    book = OrderBook.new()

    assert {:error, _} = OrderBook.place_order(book, catalogue, dosa, [])

    dosa_id = item_id(catalogue, "Masala Dosa")
    coffee_id = item_id(catalogue, "Filter Coffee")

    assert {:ok, book, first} =
             OrderBook.place_order(book, catalogue, dosa, [%{item_id: dosa_id, quantity: 5}])

    assert first.id == "o1"

    assert {:ok, _book, second} =
             OrderBook.place_order(book, catalogue, dosa, [
               %{item_id: dosa_id, quantity: 4},
               %{item_id: coffee_id, quantity: 1}
             ])

    assert second.id == "o2"
    assert second.items_total_cents == 520
  end

  test "place_order/4 rejects unknown and closed restaurants", %{
    catalogue: catalogue,
    dosa: dosa
  } do
    dosa_id = item_id(catalogue, "Masala Dosa")
    sushi = restaurant_id(catalogue, "Sushi Bar")

    assert {:error, :restaurant_not_found} =
             OrderBook.new()
             |> OrderBook.place_order(catalogue, "r999", [%{item_id: dosa_id, quantity: 5}])

    assert {:error, :restaurant_closed} =
             OrderBook.new()
             |> OrderBook.place_order(catalogue, sushi, [%{item_id: dosa_id, quantity: 5}])

    assert {:error, :empty_order} =
             OrderBook.new() |> OrderBook.place_order(catalogue, dosa, [])
  end

  test "place_order/4 rejects unknown, foreign and sold-out items", %{
    catalogue: catalogue,
    dosa: dosa
  } do
    burger_id = item_id(catalogue, "Classic Burger")
    dosa_id = item_id(catalogue, "Masala Dosa")

    assert {:error, :item_not_found} =
             OrderBook.new()
             |> OrderBook.place_order(catalogue, dosa, [%{item_id: "m999", quantity: 5}])

    assert {:error, :item_wrong_restaurant} =
             OrderBook.new()
             |> OrderBook.place_order(catalogue, dosa, [%{item_id: burger_id, quantity: 5}])

    {:ok, catalogue, _item} = Catalogue.set_item_availability(catalogue, dosa_id, false)

    assert {:error, :item_unavailable} =
             OrderBook.new()
             |> OrderBook.place_order(catalogue, dosa, [%{item_id: dosa_id, quantity: 5}])
  end

  test "place_order/4 rejects bad quantities and malformed lines", %{
    catalogue: catalogue,
    dosa: dosa
  } do
    dosa_id = item_id(catalogue, "Masala Dosa")

    for quantity <- [0, -2, 1.5, "5"] do
      assert {:error, _} =
               OrderBook.new()
               |> OrderBook.place_order(catalogue, dosa, [%{item_id: dosa_id, quantity: quantity}])
    end

    assert {:error, _} =
             OrderBook.new()
             |> OrderBook.place_order(catalogue, dosa, [%{item_id: dosa_id}])
  end

  test "place_order/4 rejects an items total below the restaurant minimum", %{
    catalogue: catalogue,
    dosa: dosa
  } do
    dosa_id = item_id(catalogue, "Masala Dosa")

    assert {:error, :below_minimum_order} =
             OrderBook.new()
             |> OrderBook.place_order(catalogue, dosa, [%{item_id: dosa_id, quantity: 1}])
  end

  test "placed lines keep the price at order time even if the menu changes", %{
    catalogue: catalogue,
    dosa: dosa
  } do
    dosa_id = item_id(catalogue, "Masala Dosa")

    assert {:ok, _book, order} =
             OrderBook.new()
             |> OrderBook.place_order(catalogue, dosa, [%{item_id: dosa_id, quantity: 5}])

    {:ok, _catalogue, updated} =
      Catalogue.update_menu_item(catalogue, dosa_id, %{price_cents: 999})

    assert updated.price_cents == 999
    assert hd(order.lines).unit_price_cents == 120
    assert order.total_cents == 750
  end
end
