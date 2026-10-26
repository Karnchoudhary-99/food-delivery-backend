defmodule FoodDeliveryBackend.CourierTest do
  use ExUnit.Case, async: true

  alias FoodDeliveryBackend.Courier

  test "new/1 builds a courier with bike and available defaults" do
    assert {:ok, courier} = Courier.new(%{id: "c1", name: "Asha"})
    assert courier.id == "c1"
    assert courier.name == "Asha"
    assert courier.vehicle == :bike
    assert courier.available? == true
    assert Courier.available?(courier)
  end

  test "new/1 accepts each vehicle and an explicit availability flag" do
    assert {:ok, scooter} = Courier.new(%{name: "Ben", vehicle: :scooter})
    assert scooter.vehicle == :scooter

    assert {:ok, car} = Courier.new(%{name: "Cleo", vehicle: :car, available?: false})
    assert car.vehicle == :car
    refute Courier.available?(car)
  end

  test "new/1 rejects a blank or missing name" do
    assert {:error, ":name must not be blank"} = Courier.new(%{name: "  "})
    assert {:error, ":name is required and must be a string"} = Courier.new(%{})
    assert {:error, ":name is required and must be a string"} = Courier.new(%{name: 42})
  end

  test "new/1 rejects an unknown vehicle or a non-boolean flag" do
    assert {:error, ":vehicle must be one of :bike, :scooter, :car"} =
             Courier.new(%{name: "Asha", vehicle: :helicopter})

    assert {:error, ":available? must be a boolean"} =
             Courier.new(%{name: "Asha", available?: "yes"})
  end
end
