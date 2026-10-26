# Food Delivery Backend

A food delivery backend in Elixir: restaurant and menu catalogues, order
placement with item totals, order lifecycle tracking, and courier assignment.

> Status: catalogue and orders done; courier assignment next.

## Roadmap

- [x] Project scaffold (Mix layout, CI, README)
- [x] Restaurant + menu catalogue (CRUD, search, availability)
- [x] Orders (placement, totals, lifecycle: placed → confirmed → preparing → out for delivery → delivered)
- [ ] Courier assignment + delivery tracking
- [ ] Self-review checklist, then public

## Quick start

```sh
mix deps.get
mix test
```

## Catalogue

The catalogue is a plain value — no process, no database — so it is easy to
test and to wrap in a GenServer later:

```elixir
alias FoodDeliveryBackend.{Catalogue, Sample}

catalogue = Sample.catalogue()
Catalogue.search_restaurants(catalogue, "dosa")
# => [%Restaurant{id: "r1", name: "Dosa House", ...}]

{:ok, catalogue, restaurant} =
  Catalogue.add_restaurant(catalogue, %{name: "Taco Stand", cuisine: "Mexican"})

{:ok, catalogue, item} =
  Catalogue.add_menu_item(catalogue, restaurant.id, %{name: "Al Pastor", price_cents: 180})

Catalogue.available_menu_items(catalogue, restaurant.id)
Catalogue.set_item_availability(catalogue, item.id, false) # sold out, still listed
Catalogue.remove_restaurant(catalogue, restaurant.id)      # also removes its menu
```

Rules enforced by the catalogue:

- Restaurant names and cuisines must be non-blank; fees and minimum orders
  must be non-negative integers.
- Menu item prices are integer cents and must be positive; an item belongs
  to exactly one restaurant and cannot be moved.
- Adding an item to an unknown restaurant fails with
  `:restaurant_not_found`; updating an unknown record fails with
  `:not_found`. Invalid input never mutates the catalogue.
- Search matches name or cuisine case-insensitively, with optional
  `:cuisine` and `:open_only` filters.

## Orders

Orders live in a plain-value `OrderBook`, validated against a `Catalogue`
at placement time:

```elixir
alias FoodDeliveryBackend.{Catalogue, OrderBook, Sample}

catalogue = Sample.catalogue()
dosa_house = Catalogue.search_restaurants(catalogue, "dosa") |> hd()
dosa = Catalogue.list_menu_items(catalogue, dosa_house.id) |> hd()

{:ok, book, order} =
  OrderBook.place_order(OrderBook.new(), catalogue, dosa_house.id, [
    %{item_id: dosa.id, quantity: 5}
  ])

order.total_cents # => 750 (600 items + 150 delivery fee)
order.status      # => :placed

{:ok, book, order} = OrderBook.advance_order(book, order.id)
order.status      # => :confirmed
```

Rules enforced at placement:

- The restaurant must exist and be open; the order must have at least
  one line.
- Every line must name an available item belonging to that restaurant;
  unknown, foreign and sold-out items are rejected.
- Quantities must be positive integers; the items total must clear the
  restaurant's minimum order.
- Line prices are snapshots from the menu at order time, so later price
  changes never rewrite a placed order.
- A failed placement changes nothing — not even the next order id.

Lifecycle: `placed → confirmed → preparing → out for delivery →
delivered`. An order can be cancelled from `placed`, `confirmed` or
`preparing`; once it is out for delivery it must run to completion.
Run the demo with `mix run examples/order_demo.exs`.

## License

MIT — see [LICENSE](LICENSE).
