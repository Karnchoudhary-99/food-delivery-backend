defmodule FoodDeliveryBackendTest do
  use ExUnit.Case, async: true

  test "greets the world" do
    assert FoodDeliveryBackend.hello() == :world
  end
end
