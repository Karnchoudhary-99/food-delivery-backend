defmodule FoodDeliveryBackend.OrderTest do
  use ExUnit.Case, async: true

  alias FoodDeliveryBackend.Order
  alias FoodDeliveryBackend.OrderLine

  defp line(price \\ 120, quantity \\ 2) do
    {:ok, line} =
      OrderLine.new(%{item_id: "m1", name: "Masala Dosa", unit_price_cents: price, quantity: quantity})

    line
  end

  defp order(attrs \\ %{}) do
    base = %{restaurant_id: "r1", lines: [line()], delivery_fee_cents: 150}
    Order.new(Map.merge(base, attrs))
  end

  test "new/1 prices items total, fee and grand total" do
    assert {:ok, placed} = order()
    assert placed.status == :placed
    assert placed.items_total_cents == 240
    assert placed.delivery_fee_cents == 150
    assert placed.total_cents == 390
  end

  test "new/1 sums several lines" do
    assert {:ok, placed} = order(%{lines: [line(120, 2), line(40, 3)]})
    assert placed.items_total_cents == 360
    assert placed.total_cents == 510
  end

  test "new/1 rejects an items total below the minimum order" do
    assert {:error, :below_minimum_order} = order(%{min_order_cents: 500})
  end

  test "new/1 accepts an items total exactly at the minimum order" do
    assert {:ok, placed} = order(%{min_order_cents: 240})
    assert placed.items_total_cents == 240
  end

  test "new/1 rejects empty lines, non-line entries and bad fees" do
    assert {:error, _} = order(%{lines: []})
    assert {:error, _} = order(%{lines: ["not a line"]})
    assert {:error, _} = order(%{delivery_fee_cents: -1})
    assert {:error, _} = order(%{restaurant_id: "  "})
  end

  test "advance/1 walks the full lifecycle in order" do
    assert {:ok, placed} = order()
    assert {:ok, confirmed} = Order.advance(placed)
    assert confirmed.status == :confirmed
    assert {:ok, preparing} = Order.advance(confirmed)
    assert preparing.status == :preparing
    assert {:ok, out} = Order.advance(preparing)
    assert out.status == :out_for_delivery
    assert {:ok, delivered} = Order.advance(out)
    assert delivered.status == :delivered
    assert Order.terminal?(delivered)
  end

  test "advance/1 fails on terminal orders" do
    assert {:ok, placed} = order()
    assert {:ok, cancelled} = Order.cancel(placed)
    assert {:error, :cannot_advance} = Order.advance(cancelled)
    assert Order.terminal?(cancelled)
  end

  test "cancel/1 works from placed, confirmed and preparing" do
    assert {:ok, placed} = order()
    assert {:ok, cancelled} = Order.cancel(placed)
    assert cancelled.status == :cancelled

    assert {:ok, confirmed} = Order.advance(placed)
    assert {:ok, _} = Order.cancel(confirmed)

    assert {:ok, preparing} = Order.advance(confirmed)
    assert {:ok, _} = Order.cancel(preparing)
  end

  test "cancel/1 fails once the order is out for delivery or delivered" do
    assert {:ok, placed} = order()

    assert {:ok, out} =
             placed |> Order.advance() |> elem(1) |> Order.advance() |> elem(1) |> Order.advance()

    assert {:error, :cannot_cancel} = Order.cancel(out)
    refute Order.terminal?(out)

    assert {:ok, delivered} = Order.advance(out)
    assert {:error, :cannot_cancel} = Order.cancel(delivered)
  end
end
