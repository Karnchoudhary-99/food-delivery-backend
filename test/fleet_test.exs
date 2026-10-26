defmodule FoodDeliveryBackend.FleetTest do
  use ExUnit.Case, async: true

  alias FoodDeliveryBackend.Catalogue
  alias FoodDeliveryBackend.Fleet
  alias FoodDeliveryBackend.OrderBook
  alias FoodDeliveryBackend.Sample

  setup do
    catalogue = Sample.catalogue()

    dosa_house =
      catalogue
      |> Catalogue.list_restaurants()
      |> Enum.find(&(&1.name == "Dosa House"))
      |> Map.fetch!(:id)

    dosa =
      catalogue
      |> Catalogue.list_menu_items(dosa_house)
      |> Enum.find(&(&1.name == "Masala Dosa"))
      |> Map.fetch!(:id)

    {:ok, book, placed} =
      OrderBook.place_order(OrderBook.new(), catalogue, dosa_house, [
        %{item_id: dosa, quantity: 5}
      ])

    {:ok, book, _confirmed} = OrderBook.advance_order(book, placed.id)
    {:ok, _book, preparing} = OrderBook.advance_order(book, placed.id)

    {:ok, fleet, courier} = Fleet.add_courier(Fleet.new(), %{name: "Asha", vehicle: :scooter})

    %{
      catalogue: catalogue,
      dosa_house: dosa_house,
      dosa: dosa,
      preparing: preparing,
      placed: placed,
      fleet: fleet,
      courier: courier
    }
  end

  test "add_courier/2 hands out sequential ids and a failed add consumes none", %{
    fleet: fleet,
    courier: courier
  } do
    assert courier.id == "c1"
    assert {:ok, fleet, second} = Fleet.add_courier(fleet, %{name: "Ben"})
    assert second.id == "c2"
    assert {:error, _} = Fleet.add_courier(fleet, %{name: "  "})
    assert {:ok, _fleet, third} = Fleet.add_courier(fleet, %{name: "Cleo"})
    assert third.id == "c2"
  end

  test "available_couriers/1 lists only free couriers", %{fleet: fleet} do
    assert {:ok, fleet, busy} = Fleet.add_courier(fleet, %{name: "Ben", available?: false})
    assert [courier_id] = fleet |> Fleet.available_couriers() |> Enum.map(& &1.id)
    assert courier_id != busy.id
    assert Fleet.get_courier(fleet, "c999") == nil
  end

  test "assign_courier/3 creates a delivery and marks the courier busy", %{
    fleet: fleet,
    courier: courier,
    preparing: preparing
  } do
    assert {:ok, fleet, delivery} = Fleet.assign_courier(fleet, preparing, courier.id)
    assert delivery.order_id == preparing.id
    assert delivery.courier_id == courier.id
    assert delivery.status == :assigned
    assert Fleet.get_courier(fleet, courier.id).available? == false
    assert [] == Fleet.available_couriers(fleet)
    assert delivery == Fleet.active_delivery_for_order(fleet, preparing.id)
    assert [delivery] == Fleet.deliveries_for_courier(fleet, courier.id)
    assert [delivery] == Fleet.deliveries_for_order(fleet, preparing.id)
  end

  test "assign_courier/3 rejects bad orders, busy couriers and double assignment", %{
    fleet: fleet,
    courier: courier,
    preparing: preparing,
    placed: placed
  } do
    assert {:error, :courier_not_found} = Fleet.assign_courier(fleet, preparing, "c999")
    assert {:error, :order_not_assignable} = Fleet.assign_courier(fleet, placed, courier.id)

    assert {:ok, fleet, _delivery} = Fleet.assign_courier(fleet, preparing, courier.id)
    assert {:error, :already_assigned} = Fleet.assign_courier(fleet, preparing, courier.id)

    assert {:ok, fleet, second} = Fleet.add_courier(fleet, %{name: "Ben"})
    assert {:error, :already_assigned} = Fleet.assign_courier(fleet, preparing, second.id)

    assert {:ok, fleet, _second_delivery} =
             Fleet.assign_courier(fleet, %{preparing | id: "o999"}, second.id)

    assert {:error, :courier_busy} =
             Fleet.assign_courier(fleet, %{preparing | id: "o998"}, courier.id)
  end

  test "advance_delivery/2 walks a delivery and frees the courier on delivery", %{
    fleet: fleet,
    courier: courier,
    preparing: preparing
  } do
    assert {:ok, fleet, delivery} = Fleet.assign_courier(fleet, preparing, courier.id)

    fleet =
      Enum.reduce([:picked_up, :in_transit, :delivered], fleet, fn status, acc ->
        assert {:ok, acc, advanced} = Fleet.advance_delivery(acc, delivery.id)
        assert advanced.status == status
        acc
      end)

    assert Fleet.get_courier(fleet, courier.id).available? == true
    assert [courier] = Fleet.available_couriers(fleet)
    assert {:error, :cannot_advance} = Fleet.advance_delivery(fleet, delivery.id)
    assert {:error, :not_found} = Fleet.advance_delivery(fleet, "d999")
  end

  test "update_delivery_location/3 tracks the courier and rejects unknown ids", %{
    fleet: fleet,
    courier: courier,
    preparing: preparing
  } do
    assert {:ok, fleet, delivery} = Fleet.assign_courier(fleet, preparing, courier.id)

    assert {:ok, _fleet, moved} =
             Fleet.update_delivery_location(fleet, delivery.id, "Near Dosa House")

    assert moved.location == "Near Dosa House"
    assert List.last(moved.history).location == "Near Dosa House"
    assert {:error, :not_found} = Fleet.update_delivery_location(fleet, "d999", "Nowhere")
  end

  test "cancel_delivery/2 frees the courier and allows a fresh assignment", %{
    fleet: fleet,
    courier: courier,
    preparing: preparing
  } do
    assert {:ok, fleet, delivery} = Fleet.assign_courier(fleet, preparing, courier.id)
    assert {:ok, fleet, cancelled} = Fleet.cancel_delivery(fleet, delivery.id)
    assert cancelled.status == :cancelled
    assert Fleet.get_courier(fleet, courier.id).available? == true
    assert nil == Fleet.active_delivery_for_order(fleet, preparing.id)
    assert {:ok, _fleet, fresh} = Fleet.assign_courier(fleet, preparing, courier.id)
    assert fresh.id != delivery.id
    assert {:error, :not_found} = Fleet.cancel_delivery(fleet, "d999")
  end

  test "cancel_delivery/2 refuses an in-transit delivery", %{
    fleet: fleet,
    courier: courier,
    preparing: preparing
  } do
    assert {:ok, fleet, delivery} = Fleet.assign_courier(fleet, preparing, courier.id)
    assert {:ok, fleet, _} = Fleet.advance_delivery(fleet, delivery.id)
    assert {:ok, fleet, _} = Fleet.advance_delivery(fleet, delivery.id)
    assert {:error, :cannot_cancel} = Fleet.cancel_delivery(fleet, delivery.id)
  end
end
