require "test_helper"

class Inventory::StockDeductorTest < ActiveSupport::TestCase
  test "skips track deduction when track requirement is zero" do
    track = InventoryItem.create!(name: "Track", component_type: :track, on_hand: 0)
    hook = InventoryItem.create!(name: "Hook", component_type: :hook, on_hand: 120)
    product = products(:sheer_panel)
    product.update!(track_inventory_item: track, hook_inventory_item: hook)

    quote_request = QuoteRequest.new(
      user: users(:customer),
      customer_reference: "ORD-NO-TRACK",
      currency: "AUD",
      valid_until: 14.days.from_now.to_date,
      notes: "No track order",
      status: :order_processing,
      customer_mode: :b2b,
      pickup_method: :delivery
    )
    quote_request.quote_items.build(
      product: product,
      line_position: 1,
      description: "No track line",
      quantity: 2,
      width: 100,
      height: 220,
      area_sqm: 2.2,
      unit_price: 100,
      line_total: 200,
      applied_rule_names: "Matrix pricing",
      width_mm: 2000,
      ceiling_drop_mm: 2200,
      track_selected: "none",
      track_metres_required: 0,
      hooks_total: 20,
      hooks_display: "20",
      brackets_total: 0,
      curtain_price: 100,
      track_price: 0
    )
    quote_request.save!

    Inventory::StockDeductor.new(quote_request: quote_request).deduct!

    assert_equal 0, track.reload.on_hand
    assert_equal 80, hook.reload.on_hand
  end
end
