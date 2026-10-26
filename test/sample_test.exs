defmodule FoodDeliveryBackend.SampleTest do
  use ExUnit.Case, async: true

  alias FoodDeliveryBackend.Catalogue
  alias FoodDeliveryBackend.Sample

  test "sample catalogue has three restaurants and eight items" do
    catalogue = Sample.catalogue()
    restaurants = Catalogue.list_restaurants(catalogue)
    assert length(restaurants) == 3
    assert Enum.map(restaurants, & &1.name) == ["Dosa House", "Burger Joint", "Sushi Bar"]

    [dosa_house, burger_joint, sushi_bar] = restaurants
    assert length(Catalogue.list_menu_items(catalogue, dosa_house.id)) == 3
    assert length(Catalogue.list_menu_items(catalogue, burger_joint.id)) == 3
    assert length(Catalogue.list_menu_items(catalogue, sushi_bar.id)) == 2
    assert sushi_bar.open? == false
  end

  test "sample menus are searchable" do
    catalogue = Sample.catalogue()
    assert [%{name: "Sushi Bar"}] = Catalogue.search_restaurants(catalogue, "sushi")

    open_restaurants = Catalogue.search_restaurants(catalogue, "", open_only: true)
    assert [%{name: "Dosa House"}] = Enum.filter(open_restaurants, &(&1.name == "Dosa House"))
  end
end
