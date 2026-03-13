require "test_helper"

class Inventory::MaxQuantityCalculatorTest < ActiveSupport::TestCase
  test "returns limiting max quantity across mapped components and auto adjusts request" do
    product = products(:sheer_panel)
    product.update!(
      track_inventory_item: InventoryItem.create!(name: "Track", component_type: :track, on_hand: 20),
      hook_inventory_item: InventoryItem.create!(name: "Hooks", component_type: :hook, on_hand: 300),
      bracket_inventory_item: InventoryItem.create!(name: "Brackets", component_type: :bracket, on_hand: 100)
    )

    result = Inventory::MaxQuantityCalculator.new(
      product: product,
      requirement_per_unit: {
        track_metres_required: 4,
        hooks_total: 72,
        brackets_total: 7
      },
      requested_quantity: 6
    ).calculate

    assert_equal 4, result.max_quantity
    assert_equal 4, result.adjusted_quantity
    assert_equal true, result.adjusted
    assert_equal "Hooks", result.limiting_component
  end

  test "returns requested quantity when no mapped inventory limits exist" do
    result = Inventory::MaxQuantityCalculator.new(
      product: products(:blackout_panel),
      requirement_per_unit: { track_metres_required: 2, hooks_total: 30 },
      requested_quantity: 5
    ).calculate

    assert_equal 5, result.max_quantity
    assert_equal 5, result.adjusted_quantity
    assert_equal false, result.adjusted
    assert_nil result.limiting_component
  end

  test "ignores track inventory when track requirement per unit is zero" do
    product = products(:sheer_panel)
    product.update!(
      track_inventory_item: InventoryItem.create!(name: "Track", component_type: :track, on_hand: 0),
      hook_inventory_item: InventoryItem.create!(name: "Hooks", component_type: :hook, on_hand: 300),
      bracket_inventory_item: InventoryItem.create!(name: "Brackets", component_type: :bracket, on_hand: 100)
    )

    result = Inventory::MaxQuantityCalculator.new(
      product: product,
      requirement_per_unit: {
        track_metres_required: 0,
        hooks_total: 72,
        brackets_total: 7
      },
      requested_quantity: 2
    ).calculate

    assert_equal 4, result.max_quantity
    assert_equal 2, result.adjusted_quantity
    assert_equal false, result.adjusted
    assert_equal "Hooks", result.limiting_component
  end
end
