defmodule FoodDeliveryBackend.OrderBookLifecycleTest do
  use ExUnit.Case, async: true

  alias FoodDeliveryBackend.Catalogue
  alias FoodDeliveryBackend.OrderBook
  alias FoodDeliveryBackend.Sample

  defp place(catalogue, dosa, dosa_id, book \\ OrderBook.new()) do
    OrderBook.place_order(book, catalogue, dosa, [%{item_id: dosa_id, quantity: 5}])
  end

  setup do
    catalogue = Sample.catalogue()

    dosa =
      catalogue
      |> Catalogue.list_restaurants()
      |> Enum.find(&(&1.name == "Dosa House"))
      |> Map.fetch!(:id)

    dosa_id =
      catalogue
      |> Catalogue.list_menu_items(dosa)
      |> Enum.find(&(&1.name == "Masala Dosa"))
      |> Map.fetch!(:id)

    %{catalogue: catalogue, dosa: dosa, dosa_id: dosa_id}
  end

  test "advance_order/2 walks an order to delivered, then refuses", %{
    catalogue: catalogue,
    dosa: dosa,
    dosa_id: dosa_id
  } do
    assert {:ok, book, order} = place(catalogue, dosa, dosa_id)
    assert order.status == :placed

    book =
      Enum.reduce([:confirmed, :preparing, :out_for_delivery, :delivered], book, fn status, acc ->
        assert {:ok, acc, advanced} = OrderBook.advance_order(acc, order.id)
        assert advanced.status == status
        acc
      end)

    assert {:error, :cannot_advance} = OrderBook.advance_order(book, order.id)
    assert {:error, :cannot_cancel} = OrderBook.cancel_order(book, order.id)
  end

  test "cancel_order/2 cancels a placed order and blocks later moves", %{
    catalogue: catalogue,
    dosa: dosa,
    dosa_id: dosa_id
  } do
    assert {:ok, book, order} = place(catalogue, dosa, dosa_id)
    assert {:ok, book, cancelled} = OrderBook.cancel_order(book, order.id)
    assert cancelled.status == :cancelled
    assert {:error, :cannot_advance} = OrderBook.advance_order(book, order.id)
    assert {:error, :cannot_cancel} = OrderBook.cancel_order(book, order.id)
  end

  test "advance/cancel on an unknown order fail with :not_found", %{
    catalogue: catalogue,
    dosa: dosa,
    dosa_id: dosa_id
  } do
    assert {:ok, book, _order} = place(catalogue, dosa, dosa_id)
    assert {:error, :not_found} = OrderBook.advance_order(book, "o999")
    assert {:error, :not_found} = OrderBook.cancel_order(book, "o999")
  end

  test "listings filter by restaurant and by status", %{
    catalogue: catalogue,
    dosa: dosa,
    dosa_id: dosa_id
  } do
    assert {:ok, book, first} = place(catalogue, dosa, dosa_id)
    assert {:ok, book, second} = place(catalogue, dosa, dosa_id, book)
    assert {:ok, book, _cancelled} = OrderBook.cancel_order(book, second.id)

    assert [first.id, second.id] == book |> OrderBook.list_orders() |> Enum.map(& &1.id)
    assert [first] == OrderBook.list_orders_by_status(book, :placed)
    assert [second] == OrderBook.list_orders_by_status(book, :cancelled)
    assert [] == OrderBook.list_orders_by_status(book, :delivered)
    assert 2 == book |> OrderBook.list_orders_for_restaurant(dosa) |> length()
    assert [] == OrderBook.list_orders_for_restaurant(book, "r999")
  end
end
