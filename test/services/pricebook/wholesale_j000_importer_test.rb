require "test_helper"

class Pricebook::CurtainPricingImporterTest < ActiveSupport::TestCase
  FakeWorkbook = Struct.new(:sheet_names, :sheet_lookup, :sheet_requests) do
    def sheets
      sheet_names
    end

    def sheet(name)
      sheet_requests << name
      sheet_lookup.fetch(name) do
        raise ArgumentError, "unexpected sheet lookup: #{name}"
      end
    end
  end

  setup do
    PriceMatrixEntry.delete_all
    TrackPriceTier.delete_all
    Product.where("sku LIKE 'PB-%'").delete_all
  end

  test "imports april 2026 workbook into four active pb templates with zero track tiers" do
    importer = build_importer(
      file_path: file_fixture("pricing_april_2026.xlsx").to_s,
      source_filename: "Pricing April 2026.xlsx"
    )

    result = importer.import!

    assert_equal 4, result.products_updated_count
    assert_equal 240, result.price_matrix_entries_count
    assert_equal 0, result.track_price_tiers_count

    assert_equal 240, PriceMatrixEntry.count
    assert_equal 0, TrackPriceTier.count
    assert_includes result.log_output, "Track tiers remain dormant for the April 2026 workbook format"

    assert_equal(
      [
        "PB-B2B-blockout-curtain-s-wave",
        "PB-B2B-sheer-curtain-s-wave",
        "PB-B2C-blockout-curtain-s-wave",
        "PB-B2C-sheer-curtain-s-wave"
      ],
      Product.where("sku LIKE 'PB-%'").active.order(:sku).pluck(:sku)
    )

    assert_equal 0, PriceMatrixEntry.where(style_name: "Pinch Pleat").count
  end

  test "archives unsupported pb pinch pleat templates and removes stale pinch pleat matrix rows" do
    stale_template = Product.create!(
      name: "Sheer Curtain (Pinch Pleat)",
      sku: "PB-B2B-SHEER-CURTAIN-PINCH-PLEAT",
      description: "Legacy imported combo",
      base_price: 0,
      pricing_mode: :per_unit,
      active: true,
      product_type: "Sheer Curtain",
      style_name: "Pinch Pleat",
      pricing_channel: "b2b"
    )

    PriceMatrixEntry.create!(
      channel: "b2b",
      product_name: "Sheer Curtain",
      style_name: "Pinch Pleat",
      width_band_min_mm: 0,
      width_band_max_mm: 1000,
      drop_band_min_mm: 0,
      drop_band_max_mm: 2500,
      price: 123,
      currency: "AUD"
    )

    importer = build_importer(
      file_path: file_fixture("pricing_april_2026.xlsx").to_s,
      source_filename: "Pricing April 2026.xlsx"
    )

    importer.import!

    stale_template.reload
    assert_not stale_template.active?
    assert_equal 0, PriceMatrixEntry.where(channel: "b2b", product_name: "Sheer Curtain", style_name: "Pinch Pleat").count
  end

  test "uses only the curtain pricing sheet" do
    pricing_sheet = Object.new
    workbook = build_workbook(
      sheet_names: [ "Curtain Pricing" ],
      sheet_lookup: { "Curtain Pricing" => pricing_sheet }
    )
    importer = build_importer(file_path: "single_sheet.xlsx")

    with_stubbed_workbook(workbook) do
      with_stubbed_methods(importer, [
        [ :build_matrix_rows, ->(sheet) { assert_same pricing_sheet, sheet; [] } ],
        [ :upsert_product_templates, [ 0, 0 ] ],
        [ :replace_price_matrix_entries!, 0 ]
      ]) do
        result = importer.import!

        assert_equal 0, result.products_updated_count
        assert_equal 0, result.price_matrix_entries_count
        assert_equal 0, result.track_price_tiers_count
        assert_equal [ "Curtain Pricing" ], workbook.sheet_requests
      end
    end
  end

  test "raises a clear error when curtain pricing sheet is missing" do
    workbook = build_workbook(sheet_names: [ "Sheet1" ], sheet_lookup: {})
    importer = build_importer(file_path: "missing_pricing.xlsx")

    with_stubbed_method(Roo::Excelx, :new, ->(*) { workbook }) do
      error = assert_raises(ArgumentError) { importer.import! }

      assert_match "Pricing sheet not found", error.message
      assert_match "Curtain Pricing", error.message
      assert_match "Sheet1", error.message
      assert_empty workbook.sheet_requests
    end
  end

  test "legacy wholesale j000 importer remains available as a compatibility wrapper" do
    importer = build_importer(
      file_path: file_fixture("pricing_april_2026.xlsx").to_s,
      source_filename: "Pricing April 2026.xlsx",
      importer_class: Pricebook::WholesaleJ000Importer
    )

    result = importer.import!

    assert_instance_of Pricebook::WholesaleJ000Importer, importer
    assert_kind_of Pricebook::CurtainPricingImporter, importer
    assert_equal 4, result.products_updated_count
    assert_equal 240, result.price_matrix_entries_count
  end

  private

  def build_importer(file_path:, source_filename: File.basename(file_path), importer_class: Pricebook::CurtainPricingImporter)
    importer_class.new(
      file_path: file_path,
      source_filename: source_filename,
      imported_by: users(:admin)
    )
  end

  def build_workbook(sheet_names:, sheet_lookup:)
    FakeWorkbook.new(sheet_names, sheet_lookup, [])
  end

  def with_stubbed_workbook(workbook)
    with_stubbed_method(ActiveRecord::Base, :transaction, ->(*, &block) { block.call }) do
      with_stubbed_method(Roo::Excelx, :new, ->(*) { workbook }) do
        yield
      end
    end
  end

  def with_stubbed_methods(target, replacements, &block)
    method_name, replacement = replacements.first
    return yield unless method_name

    with_stubbed_method(target, method_name, replacement) do
      with_stubbed_methods(target, replacements.drop(1), &block)
    end
  end

  def with_stubbed_method(target, method_name, replacement)
    singleton = class << target; self; end
    original_name = "__codex_original_#{method_name}".to_sym

    singleton.alias_method original_name, method_name
    singleton.define_method(method_name) do |*args, &block|
      if replacement.respond_to?(:call)
        replacement.call(*args, &block)
      else
        replacement
      end
    end

    yield
  ensure
    singleton.alias_method method_name, original_name
    singleton.remove_method original_name
  end
end
