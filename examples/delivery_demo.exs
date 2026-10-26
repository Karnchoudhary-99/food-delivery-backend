# Assigns a courier to a sample order and walks the delivery to the door.
#
# Run with: mix run examples/delivery_demo.exs

alias FoodDeliveryBackend.{Catalogue, Fleet, OrderBook, Sample}

catalogue = Sample.catalogue()

dosa_house =
  catalogue
  |> Catalogue.list_restaurants()
  |> Enum.find(&(&1.name == "Dosa House"))

dosa =
  catalogue
  |> Catalogue.list_menu_items(dosa_house.id)
  |> Enum.find(&(&1.name == "Masala Dosa"))

{:ok, book, order} =
  OrderBook.place_order(OrderBook.new(), catalogue, dosa_house.id, [
    %{item_id: dosa.id, quantity: 5}
  ])

{:ok, book, order} = OrderBook.advance_order(book, order.id)
{:ok, book, order} = OrderBook.advance_order(book, order.id)
IO.puts("Order #{order.id} is #{order.status} and ready for a courier.")

{:ok, fleet, courier} = Fleet.add_courier(Fleet.new(), %{name: "Asha", vehicle: :scooter})
{:ok, fleet, delivery} = Fleet.assign_courier(fleet, order, courier.id)
IO.puts("Assigned #{courier.name} (#{courier.vehicle}) to order #{order.id}.")

{:ok, fleet, delivery} = Fleet.advance_delivery(fleet, delivery.id)
{:ok, fleet, delivery} = Fleet.update_delivery_location(fleet, delivery.id, "Picked up at Dosa House")
{:ok, book, order} = OrderBook.advance_order(book, order.id)
{:ok, fleet, delivery} = Fleet.advance_delivery(fleet, delivery.id)
{:ok, fleet, delivery} = Fleet.update_delivery_location(fleet, delivery.id, "Two streets away")
{:ok, book, order} = OrderBook.advance_order(book, order.id)
{:ok, _fleet, delivery} = Fleet.advance_delivery(fleet, delivery.id)

IO.puts("Order is #{order.status}; delivery is #{delivery.status}. Tracking timeline:")

Enum.each(delivery.history, fn event ->
  IO.puts("  #{event.seq}. #{event.status}#{if event.location, do: " — #{event.location}", else: ""}")
end)
