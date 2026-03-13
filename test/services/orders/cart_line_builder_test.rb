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

    TrackPriceTier.create!(
      track_name: "shared",
      width_band_min_mm: 0,
      width_band_max_mm: 6000,
      price: 130,
      currency: "AUD"
    )
  end

  test "blank track selection defaults to shared" do
    result = Orders::CartLineBuilder.new(
      customer_mode: :b2b,
      product: @product,
      attributes: {
        "width_mm" => 3830,
        "ceiling_drop_mm" => 2410,
        "quantity" => 1,
        "opening_type" => "single_open",
        "finished_floor_mode" => "just_off_floor",
        "track_selected" => ""
      }
    ).build

    assert_nil result.error
    assert_equal "shared", result.line["track_selected"]
    assert_equal BigDecimal("130.0"), result.line["track_price"].to_d
  end

  test "explicit no track keeps none and removes track charges and requirements" do
    result = Orders::CartLineBuilder.new(
      customer_mode: :b2b,
      product: @product,
      attributes: {
        "width_mm" => 3830,
        "ceiling_drop_mm" => 2410,
        "quantity" => 1,
        "opening_type" => "single_open",
        "finished_floor_mode" => "just_off_floor",
        "track_selected" => "none"
      }
    ).build

    assert_nil result.error
    assert_equal "none", result.line["track_selected"]
    assert_equal BigDecimal("0"), result.line["track_price"].to_d
    assert_equal 0, result.line["track_metres_required"]
  end
end
