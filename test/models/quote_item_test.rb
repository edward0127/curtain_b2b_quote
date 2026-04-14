require "test_helper"

class QuoteItemTest < ActiveSupport::TestCase
  test "active curtain-only snapshots use the new presentation helpers" do
    item = quote_items(:one_line_one)
    item.product.update!(product_type: "Sheer Curtain", style_name: "S Wave")
    item.update!(
      width_mm: 3830,
      ceiling_drop_mm: 2410,
      opening_type: :double_open,
      material_name: "Snow Sheer",
      material_number: "SN-01",
      hooks_display: "30 and 30",
      hooks_total: 60,
      curtain_price: 440,
      track_price: 0,
      track_metres_required: 0,
      track_selected: nil
    )

    assert item.active_curtain_only_pricing?
    assert_not item.show_track_details?
    assert_equal "S Wave", item.style_label
    assert_equal "Snow Sheer SN-01", item.material_with_number_label
    assert_equal "C/O", item.opening_code_label
    assert_equal "30 and 30", item.hooks_label
    assert_equal "", item.track_length_label
  end

  test "legacy separate track detection still works for historical rows" do
    item = quote_items(:one_line_one)
    item.update!(
      width_mm: 3830,
      ceiling_drop_mm: 2410,
      track_selected: "M",
      track_price: 130,
      track_metres_required: 4
    )

    assert item.legacy_separate_track?
    assert item.show_track_details?
    assert_equal "M", item.separate_track_code
    assert_equal "3830", item.track_length_label
  end

  test "pinch pleat styles are detected for legacy heading fallbacks" do
    item = quote_items(:one_line_one)
    item.product.update!(product_type: "Sheer Curtain", style_name: "Pinch Pleat")

    assert item.pinch_pleat_style?
  end
end
