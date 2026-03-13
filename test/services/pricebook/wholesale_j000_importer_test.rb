require "test_helper"

class Pricebook::WholesaleJ000ImporterTest < ActiveSupport::TestCase
  setup do
    PriceMatrixEntry.delete_all
    TrackPriceTier.delete_all
    Product.where("sku LIKE 'PB-%'").delete_all
  end

  test "imports product templates, matrix rows, and shared track tiers from fixture workbook" do
    unsupported = Product.create!(
      name: "Sheer Curtain (Pinch Pleat)",
      sku: "PB-B2C-SHEER-CURTAIN-PINCH-PLEAT",
      description: "Legacy unsupported combo",
      base_price: 0,
      pricing_mode: :per_unit,
      active: true,
      product_type: "Sheer Curtain",
      style_name: "Pinch Pleat",
      pricing_channel: "b2c"
    )

    importer = Pricebook::WholesaleJ000Importer.new(
      file_path: file_fixture("wholesale_j000.xlsx").to_s,
      source_filename: "WHOLESALE Quote Form Tailored - J000.xlsx",
      imported_by: users(:admin)
    )

    result = importer.import!

    assert_equal 6, result.products_updated_count
    assert_equal 330, result.price_matrix_entries_count
    assert_equal 18, result.track_price_tiers_count

    assert_equal 330, PriceMatrixEntry.count
    assert_equal 18, TrackPriceTier.count
    assert_operator Product.where("sku LIKE 'PB-%'").count, :>=, 6

    pinch_entries = PriceMatrixEntry.where(channel: "b2b", product_name: "Sheer Curtain", style_name: "Pinch Pleat")
    assert_operator pinch_entries.count, :>, 0

    pinch_template = Product.find_by!(product_type: "Sheer Curtain", style_name: "Pinch Pleat", pricing_channel: "b2b")
    sample_entry = pinch_entries.first
    sample_width = (sample_entry.width_band_min_mm + sample_entry.width_band_max_mm) / 2
    sample_drop = (sample_entry.drop_band_min_mm + sample_entry.drop_band_max_mm) / 2

    pricing = Pricing::MatrixCalculator.new(
      customer_mode: :b2b,
      product: pinch_template,
      width_mm: sample_width,
      drop_mm: sample_drop,
      track_selected: "shared"
    ).calculate

    assert_equal sample_entry.price.to_d, pricing.curtain_price

    unsupported.reload
    assert_not unsupported.active?
  end
end
