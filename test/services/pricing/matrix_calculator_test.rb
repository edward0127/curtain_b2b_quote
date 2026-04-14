require "test_helper"

class Pricing::MatrixCalculatorTest < ActiveSupport::TestCase
  setup do
    PriceMatrixEntry.delete_all
    TrackPriceTier.delete_all
    Product.where("sku LIKE 'PB-%'").delete_all

    Pricebook::CurtainPricingImporter.new(
      file_path: file_fixture("pricing_april_2026.xlsx").to_s,
      source_filename: "Pricing April 2026.xlsx",
      imported_by: users(:admin)
    ).import!
  end

  test "returns the april 2026 curtain matrix price only for known b2b dimensions" do
    template = Product.find_by!(product_type: "Sheer Curtain", style_name: "S Wave", pricing_channel: "b2b")

    result = Pricing::MatrixCalculator.new(
      customer_mode: :b2b,
      product: template,
      width_mm: 3830,
      drop_mm: 2410
    ).calculate

    assert_equal BigDecimal("440"), result.curtain_price
    assert_equal BigDecimal("0"), result.track_price
    assert_equal BigDecimal("440"), result.line_total
  end

  test "ignores dormant track tiers for active pricing" do
    template = Product.find_by!(product_type: "Sheer Curtain", style_name: "S Wave", pricing_channel: "b2b")
    TrackPriceTier.create!(
      track_name: "M",
      width_band_min_mm: 0,
      width_band_max_mm: 6000,
      price: 999,
      currency: "AUD"
    )

    result = Pricing::MatrixCalculator.new(
      customer_mode: :b2b,
      product: template,
      width_mm: 3830,
      drop_mm: 2410
    ).calculate

    assert_equal BigDecimal("440"), result.curtain_price
    assert_equal BigDecimal("0"), result.track_price
    assert_equal BigDecimal("440"), result.line_total
  end
end
