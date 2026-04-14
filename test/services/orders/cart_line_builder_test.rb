require "test_helper"

class Orders::CartLineBuilderTest < ActiveSupport::TestCase
  setup do
    PriceMatrixEntry.delete_all
    TrackPriceTier.delete_all

    @product = products(:sheer_panel)
    @product.update!(
      product_type: "Sheer Curtain",
      style_name: "S Wave",
      pricing_channel: "b2b"
    )

    PriceMatrixEntry.create!(
      channel: "b2b",
      product_name: "Sheer Curtain",
      style_name: "S Wave",
      width_band_min_mm: 0,
      width_band_max_mm: 6000,
      drop_band_min_mm: 0,
      drop_band_max_mm: 4000,
      price: 274.4,
      currency: "AUD"
    )
  end

  test "stores neutral track fields and line total equals the curtain price" do
    result = Orders::CartLineBuilder.new(
      customer_mode: :b2b,
      product: @product,
      attributes: {
        "width_mm" => 3830,
        "ceiling_drop_mm" => 2410,
        "quantity" => 1,
        "opening_type" => "single_open",
        "finished_floor_mode" => "just_off_floor",
        "track_selected" => "M"
      }
    ).build

    assert_nil result.error
    assert_equal "", result.line["track_selected"]
    assert_equal 0, result.line["track_metres_required"]
    assert_equal BigDecimal("0"), result.line["track_price"].to_d
    assert_equal BigDecimal("274.4"), result.line["curtain_price"].to_d
    assert_equal BigDecimal("274.4"), result.line["unit_price"].to_d
    assert_equal BigDecimal("274.4"), result.line["line_total"].to_d
  end
end
