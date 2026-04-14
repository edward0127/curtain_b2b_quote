require "bigdecimal"
require "bigdecimal/util"
require "set"

module Pricebook
  # Active importer for the April 2026 single-sheet curtain pricing workbook.
  # The persisted import_type stays as `wholesale_j000` so old import history remains unchanged.
  class CurtainPricingImporter
    IMPORT_TYPE = "wholesale_j000".freeze
    PRICING_SHEET_NAME = "Curtain Pricing".freeze

    Result = Struct.new(
      :products_updated_count,
      :price_matrix_entries_count,
      :track_price_tiers_count,
      :log_output,
      keyword_init: true
    )

    MATRIX_SECTIONS = [
      {
        channel: "b2c",
        product_name: "Sheer Curtain",
        style_name: "S Wave",
        width_min_row: 6,
        width_max_row: 7,
        width_start_col: 4,
        width_end_col: 15,
        drop_start_row: 8,
        drop_end_row: 12,
        drop_min_col: 2,
        drop_max_col: 3
      },
      {
        channel: "b2c",
        product_name: "Blockout Curtain",
        style_name: "S Wave",
        width_min_row: 18,
        width_max_row: 19,
        width_start_col: 4,
        width_end_col: 15,
        drop_start_row: 20,
        drop_end_row: 24,
        drop_min_col: 2,
        drop_max_col: 3
      },
      {
        channel: "b2b",
        product_name: "Sheer Curtain",
        style_name: "S Wave",
        width_min_row: 6,
        width_max_row: 7,
        width_start_col: 19,
        width_end_col: 30,
        drop_start_row: 8,
        drop_end_row: 12,
        drop_min_col: 17,
        drop_max_col: 18
      },
      {
        channel: "b2b",
        product_name: "Blockout Curtain",
        style_name: "S Wave",
        width_min_row: 16,
        width_max_row: 17,
        width_start_col: 19,
        width_end_col: 30,
        drop_start_row: 18,
        drop_end_row: 22,
        drop_min_col: 17,
        drop_max_col: 18
      }
    ].freeze

    LEGACY_UNSUPPORTED_TEMPLATE_COMBOS = [
      [ "b2b", "Sheer Curtain", "Pinch Pleat" ],
      [ "b2b", "Blockout Curtain", "Pinch Pleat" ]
    ].freeze

    def initialize(file_path:, source_filename:, imported_by:)
      @file_path = file_path
      @source_filename = source_filename
      @imported_by = imported_by
      @log_lines = []
    end

    def import!
      workbook = Roo::Excelx.new(file_path)
      pricing_sheet = workbook.sheet(resolve_pricing_sheet(workbook))

      products_count = 0
      matrix_rows = []
      archived_templates_count = 0
      stale_matrix_rows_removed_count = 0

      ActiveRecord::Base.transaction do
        matrix_rows = build_matrix_rows(pricing_sheet)
        products_count, archived_templates_count = upsert_product_templates(matrix_rows)
        stale_matrix_rows_removed_count = replace_price_matrix_entries!(matrix_rows)
      end

      log("Imported #{products_count} product templates.")
      log("Imported #{matrix_rows.size} price matrix rows.")
      log("Archived #{archived_templates_count} unsupported importer-managed PB templates.")
      log("Removed #{stale_matrix_rows_removed_count} stale importer-managed matrix rows.")
      log("Track tiers remain dormant for the April 2026 workbook format and were recorded as 0.")

      Result.new(
        products_updated_count: products_count,
        price_matrix_entries_count: matrix_rows.size,
        track_price_tiers_count: 0,
        log_output: log_lines.join("\n")
      )
    end

    private

    attr_reader :file_path, :source_filename, :imported_by, :log_lines

    def resolve_pricing_sheet(workbook)
      available_sheets = workbook.sheets
      return PRICING_SHEET_NAME if available_sheets.include?(PRICING_SHEET_NAME)

      available_sheet_list = available_sheets.presence&.join(", ") || "(none)"
      raise ArgumentError, "Pricing sheet not found. Expected '#{PRICING_SHEET_NAME}'. Available sheets: #{available_sheet_list}"
    end

    def upsert_product_templates(matrix_rows)
      supported_templates = matrix_rows.map { |row| [ row[:channel], row[:product_name], row[:style_name] ] }.uniq
      return [ 0, 0 ] if supported_templates.empty?

      updates = 0

      supported_templates.each do |channel, product_type, style_name|
        sku = [
          "PB",
          channel.upcase,
          slugify(product_type),
          slugify(style_name)
        ].join("-")

        product = Product.find_or_initialize_by(sku: sku)
        product.name = "#{product_type} (#{style_name})"
        product.description = "Imported from the April 2026-style Curtain Pricing workbook by #{imported_by.email}"
        product.base_price = 0
        product.pricing_mode = :per_unit
        product.active = true
        product.product_type = product_type
        product.style_name = style_name
        product.pricing_channel = channel
        product.save!
        updates += 1
      end

      archived_templates_count = deactivate_unsupported_templates!(supported_templates)
      [ updates, archived_templates_count ]
    end

    def deactivate_unsupported_templates!(supported_templates)
      supported_lookup = supported_templates.to_set
      archived_templates_count = 0

      Product.where("sku LIKE 'PB-%'").find_each do |product|
        key = [ product.pricing_channel.to_s, product.product_type.to_s, product.style_name.to_s ]
        next if supported_lookup.include?(key)
        next unless product.pricing_channel.present? && product.product_type.present? && product.style_name.present?
        next unless product.active?

        product.update!(active: false)
        archived_templates_count += 1
      end

      archived_templates_count
    end

    def build_matrix_rows(sheet)
      rows = []

      MATRIX_SECTIONS.each do |section|
        width_bands = parse_width_bands(
          sheet,
          width_min_row: section[:width_min_row],
          width_max_row: section[:width_max_row],
          width_start_col: section[:width_start_col],
          width_end_col: section[:width_end_col]
        )

        section[:drop_start_row].upto(section[:drop_end_row]) do |row_idx|
          drop_min = integer_cell(sheet, row_idx, section[:drop_min_col])
          drop_max = integer_cell(sheet, row_idx, section[:drop_max_col])
          next if drop_min.nil? || drop_max.nil?

          width_bands.each do |band|
            price = decimal_cell(sheet, row_idx, band[:col])
            next if price.nil?

            rows << {
              channel: section[:channel],
              product_name: section[:product_name],
              style_name: section[:style_name],
              width_band_min_mm: band[:min],
              width_band_max_mm: band[:max],
              drop_band_min_mm: drop_min,
              drop_band_max_mm: drop_max,
              price: price,
              currency: "AUD",
              source_version: source_filename
            }
          end
        end
      end

      rows
    end

    def parse_width_bands(sheet, width_min_row:, width_max_row:, width_start_col:, width_end_col:)
      bands = []
      width_start_col.upto(width_end_col) do |col_idx|
        min_value = integer_cell(sheet, width_min_row, col_idx)
        max_value = integer_cell(sheet, width_max_row, col_idx)
        next if min_value.nil? || max_value.nil?

        bands << { col: col_idx, min: min_value, max: max_value }
      end

      bands
    end

    def replace_price_matrix_entries!(rows)
      supported_templates = rows.map { |row| [ row[:channel], row[:product_name], row[:style_name] ] }.uniq
      supported_templates.each do |channel, product_name, style_name|
        PriceMatrixEntry.where(
          channel: channel,
          product_name: product_name,
          style_name: style_name
        ).delete_all
      end
      stale_removed_count = remove_stale_importer_matrix_entries!(supported_templates)

      return stale_removed_count if rows.empty?

      timestamp = Time.current
      payload = rows.map do |row|
        row.merge(created_at: timestamp, updated_at: timestamp)
      end

      PriceMatrixEntry.upsert_all(payload, unique_by: :index_price_matrix_entries_on_lookup_key)
      stale_removed_count
    end

    def remove_stale_importer_matrix_entries!(supported_templates)
      supported_lookup = supported_templates.to_set
      importer_combos = Product.where("sku LIKE 'PB-%'").pluck(:pricing_channel, :product_type, :style_name).uniq
      stale_templates = (importer_combos + LEGACY_UNSUPPORTED_TEMPLATE_COMBOS).uniq
      removed_count = 0

      stale_templates.each do |channel, product_name, style_name|
        next if channel.blank? || product_name.blank? || style_name.blank?
        next if supported_lookup.include?([ channel, product_name, style_name ])
        next if Product.where.not("sku LIKE 'PB-%'").where(
          pricing_channel: channel,
          product_type: product_name,
          style_name: style_name,
          active: true
        ).exists?

        removed_count += PriceMatrixEntry.where(
          channel: channel,
          product_name: product_name,
          style_name: style_name
        ).delete_all
      end

      removed_count
    end

    def integer_cell(sheet, row, col)
      value = sheet.cell(row, col)
      return nil if value.blank?

      value.to_i
    end

    def decimal_cell(sheet, row, col)
      value = sheet.cell(row, col)
      return nil if value.blank?

      value.to_d.round(2)
    end

    def slugify(raw)
      raw.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-+\z/, "")
    end

    def log(message)
      log_lines << message
    end
  end
end
