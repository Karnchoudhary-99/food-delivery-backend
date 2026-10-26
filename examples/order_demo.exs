# Places a sample order, walks it two lifecycle steps, and prints the result.
#
# Run with: mix run examples/order_demo.exs

alias FoodDeliveryBackend.{Catalogue, OrderBook, Sample}

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

IO.puts("Placed #{order.id} at #{dosa_house.name}: #{order.total_cents} cents " <>
          "(#{order.items_total_cents} items + #{order.delivery_fee_cents} fee)")

{:ok, book, order} = OrderBook.advance_order(book, order.id)
{:ok, _book, order} = OrderBook.advance_order(book, order.id)
IO.puts("After two advances the order is #{order.status}.")
