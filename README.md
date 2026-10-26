# Food Delivery Backend

A food delivery backend in Elixir: restaurant and menu catalogues, order
placement with item totals, order lifecycle tracking, and courier assignment.

> Status: restaurant + menu catalogue done; orders and courier assignment next.

## Roadmap

- [x] Project scaffold (Mix layout, CI, README)
- [x] Restaurant + menu catalogue (CRUD, search, availability)
- [ ] Orders (placement, totals, lifecycle: placed → confirmed → preparing → out for delivery → delivered)
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

## License

MIT — see [LICENSE](LICENSE).
