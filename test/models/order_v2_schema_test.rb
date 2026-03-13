require "test_helper"

class OrderV2SchemaTest < ActiveSupport::TestCase
  test "phase one columns exist on quote request and quote item" do
    %w[
      customer_mode
      customer_name
      company_name
      customer_email
      customer_phone
      delivery_address
      billing_address
      pickup_method
      created_by_user_id
      submitted_at
      ready_for_pick_up_at
      completed_at
      cancelled_at
    ].each do |column_name|
      assert_includes QuoteRequest.column_names, column_name
    end

    %w[
      location_name
      track_selected
      fixing
      opening_type
      opening_code
      width_mm
      ceiling_drop_mm
      finished_floor_mode
      factory_drop_mm
      material_name
      material_number
      lv_name
      high_temp_custom
      width_notes
      wand_required
      wand_quantity
      end_cap_quantity
      stopper_quantity
      wand_hook_quantity
      curtain_price
      track_price
      hooks_display
      hooks_total
      brackets_total
      track_metres_required
    ].each do |column_name|
      assert_includes QuoteItem.column_names, column_name
    end
  end

  test "phase one pricing and inventory tables exist" do
    connection = ActiveRecord::Base.connection

    assert connection.data_source_exists?("price_matrix_entries")
    assert connection.data_source_exists?("track_price_tiers")
    assert connection.data_source_exists?("inventory_items")
  end

  test "inventory mappings exist on product" do
    %w[
      track_inventory_item_id
      hook_inventory_item_id
      bracket_inventory_item_id
      wand_inventory_item_id
      end_cap_inventory_item_id
      stopper_inventory_item_id
      wand_hook_inventory_item_id
    ].each do |column_name|
      assert_includes Product.column_names, column_name
    end
  end

  test "pricing and inventory models validate core attributes" do
    matrix = PriceMatrixEntry.new(
      channel: "b2b",
      product_name: "Sheer",
      style_name: "S-Wave",
      width_band_min_mm: 0,
      width_band_max_mm: 3000,
      drop_band_min_mm: 0,
      drop_band_max_mm: 3200,
      price: 120.50,
      currency: "AUD"
    )
    assert matrix.valid?

    track_tier = TrackPriceTier.new(
      track_name: "Standard Track",
      width_band_min_mm: 0,
      width_band_max_mm: 3000,
      price: 49.99,
      currency: "AUD"
    )
    assert track_tier.valid?

    stock_item = InventoryItem.new(
      name: "Standard Track Rail",
      component_type: :track,
      on_hand: 50
    )
    assert stock_item.valid?
  end
end
