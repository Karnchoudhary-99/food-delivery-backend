defmodule FoodDeliveryBackend.DeliveryTest do
  use ExUnit.Case, async: true

  alias FoodDeliveryBackend.Delivery

  defp new_delivery do
    {:ok, delivery} = Delivery.new(%{id: "d1", order_id: "o1", courier_id: "c1"})
    delivery
  end

  test "new/1 starts assigned with a one-event history" do
    delivery = new_delivery()
    assert delivery.status == :assigned
    assert delivery.location == nil
    assert delivery.history == [%{seq: 1, status: :assigned, location: nil}]
    refute Delivery.terminal?(delivery)
  end

  test "new/1 rejects blank or missing order and courier ids" do
    assert {:error, "order_id must not be blank"} =
             Delivery.new(%{order_id: " ", courier_id: "c1"})

    assert {:error, "courier_id is required and must be a string"} =
             Delivery.new(%{order_id: "o1"})
  end

  test "advance/1 walks a delivery to delivered, then refuses" do
    delivery = new_delivery()

    delivery =
      Enum.reduce([:picked_up, :in_transit, :delivered], delivery, fn status, acc ->
        assert {:ok, advanced} = Delivery.advance(acc)
        assert advanced.status == status
        advanced
      end)

    assert length(delivery.history) == 4
    assert Enum.map(delivery.history, & &1.seq) == [1, 2, 3, 4]

    assert Enum.map(delivery.history, & &1.status) == [
             :assigned,
             :picked_up,
             :in_transit,
             :delivered
           ]

    assert Delivery.terminal?(delivery)
    assert {:error, :cannot_advance} = Delivery.advance(delivery)
    assert {:error, :delivery_finished} = Delivery.update_location(delivery, "Depot")
  end

  test "update_location/2 records the location without changing status" do
    delivery = new_delivery()
    assert {:ok, moved} = Delivery.update_location(delivery, "Restaurant door")
    assert moved.status == :assigned
    assert moved.location == "Restaurant door"
    assert List.last(moved.history) == %{seq: 2, status: :assigned, location: "Restaurant door"}

    assert {:ok, advanced} = Delivery.advance(moved)
    assert advanced.location == "Restaurant door"
    assert List.last(advanced.history).location == "Restaurant door"
  end

  test "update_location/2 rejects blank and non-string locations" do
    delivery = new_delivery()
    assert {:error, "location must not be blank"} = Delivery.update_location(delivery, "  ")
    assert {:error, "location must be a string"} = Delivery.update_location(delivery, 42)
  end

  test "cancel/1 works from assigned and picked up, not from in transit" do
    assert {:ok, cancelled} = new_delivery() |> Delivery.cancel()
    assert cancelled.status == :cancelled
    assert Delivery.terminal?(cancelled)
    assert {:error, :cannot_advance} = Delivery.advance(cancelled)
    assert {:error, :cannot_cancel} = Delivery.cancel(cancelled)

    {:ok, picked_up} = new_delivery() |> Delivery.advance()
    assert {:ok, cancelled} = Delivery.cancel(picked_up)
    assert cancelled.status == :cancelled

    {:ok, picked_up} = Delivery.advance(new_delivery())
    {:ok, in_transit} = Delivery.advance(picked_up)
    assert {:error, :cannot_cancel} = Delivery.cancel(in_transit)
  end
end
