require "test_helper"

class Pricing::MatrixCalculatorTest < ActiveSupport::TestCase
  setup do
    PriceMatrixEntry.delete_all
    TrackPriceTier.delete_all
    Product.where("sku LIKE 'PB-%'").delete_all

    Pricebook::WholesaleJ000Importer.new(
      file_path: file_fixture("wholesale_j000.xlsx").to_s,
      source_filename: "WHOLESALE Quote Form Tailored - J000.xlsx",
      imported_by: users(:admin)
    ).import!
  end

  test "returns expected curtain and track prices for known b2b sample dimensions" do
    template = Product.find_by!(product_type: "Sheer Curtain", style_name: "S Wave", pricing_channel: "b2b")

    result = Pricing::MatrixCalculator.new(
      customer_mode: :b2b,
      product: template,
      width_mm: 3830,
      drop_mm: 2410,
      track_selected: "M"
    ).calculate

    assert_equal BigDecimal("274.4"), result.curtain_price
    assert_equal BigDecimal("130.0"), result.track_price
    assert_equal BigDecimal("404.4"), result.line_total
  end

  test "blank track selection defaults to shared track tier" do
    template = Product.find_by!(product_type: "Sheer Curtain", style_name: "S Wave", pricing_channel: "b2b")
    shared_tier = TrackPriceTier.where(track_name: "shared")
      .where("width_band_min_mm <= ? AND width_band_max_mm >= ?", 3830, 3830)
      .first
    assert_not_nil shared_tier

    result = Pricing::MatrixCalculator.new(
      customer_mode: :b2b,
      product: template,
      width_mm: 3830,
      drop_mm: 2410,
      track_selected: ""
    ).calculate

    assert_equal shared_tier.price.to_d, result.track_price
  end

  test "explicit no track returns zero track price" do
    template = Product.find_by!(product_type: "Sheer Curtain", style_name: "S Wave", pricing_channel: "b2b")

    result = Pricing::MatrixCalculator.new(
      customer_mode: :b2b,
      product: template,
      width_mm: 3830,
      drop_mm: 2410,
      track_selected: "none"
    ).calculate

    assert_equal BigDecimal("274.4"), result.curtain_price
    assert_equal BigDecimal("0"), result.track_price
    assert_equal BigDecimal("274.4"), result.line_total
  end
end
