require "bigdecimal"
require "bigdecimal/util"
require "set"

module Pricebook
  class WholesaleJ000Importer
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
        width_end_col: 14,
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
        width_end_col: 14,
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
        width_end_col: 29,
        drop_start_row: 8,
        drop_end_row: 12,
        drop_min_col: 17,
        drop_max_col: 18
      },
      {
        channel: "b2b",
        product_name: "Sheer Curtain",
        style_name: "Pinch Pleat",
        width_min_row: 16,
        width_max_row: 17,
        width_start_col: 19,
        width_end_col: 29,
        drop_start_row: 18,
        drop_end_row: 22,
        drop_min_col: 17,
        drop_max_col: 18
      },
      {
        channel: "b2b",
        product_name: "Blockout Curtain",
        style_name: "S Wave",
        width_min_row: 26,
        width_max_row: 27,
        width_start_col: 19,
        width_end_col: 29,
        drop_start_row: 28,
        drop_end_row: 32,
        drop_min_col: 17,
        drop_max_col: 18
      },
      {
        channel: "b2b",
        product_name: "Blockout Curtain",
        style_name: "Pinch Pleat",
        width_min_row: 35,
        width_max_row: 36,
        width_start_col: 19,
        width_end_col: 29,
        drop_start_row: 37,
        drop_end_row: 41,
        drop_min_col: 17,
        drop_max_col: 18
      }
    ].freeze

    TRACK_ROWS_RANGE = (34..39).freeze
    TRACK_MAX_WIDTH_COL = 2
    TRACK_PRICE_COL = 3

    def initialize(file_path:, source_filename:, imported_by:)
      @file_path = file_path
      @source_filename = source_filename
      @imported_by = imported_by
      @log_lines = []
    end

    def import!
      pricing_sheet = Roo::Excelx.new(file_path).sheet("Curtain Pricing")
      dropdown_sheet = Roo::Excelx.new(file_path).sheet("Dropdowns")

      track_codes = parse_track_codes(dropdown_sheet)

      products_count = 0
      matrix_rows = []
      track_rows = []

      ActiveRecord::Base.transaction do
        matrix_rows = build_matrix_rows(pricing_sheet)
        products_count = upsert_product_templates(matrix_rows)
        replace_price_matrix_entries!(matrix_rows)
        track_rows = build_track_tier_rows(pricing_sheet, track_codes)
        replace_track_price_tiers!(track_rows)
      end

      log("Imported #{products_count} product templates.")
      log("Imported #{matrix_rows.size} price matrix rows.")
      log("Imported #{track_rows.size} track tier rows.")

      Result.new(
        products_updated_count: products_count,
        price_matrix_entries_count: matrix_rows.size,
        track_price_tiers_count: track_rows.size,
        log_output: log_lines.join("\n")
      )
    end

    private

    attr_reader :file_path, :source_filename, :imported_by, :log_lines

    def parse_track_codes(sheet)
      values = []
      2.upto(30) do |row|
        raw = sheet.cell(row, 4)
        code = raw.to_s.strip
        next if code.blank? || code.start_with?("*")

        values << code
      end

      values.uniq.presence || [ "shared" ]
    end

    def upsert_product_templates(matrix_rows)
      supported_templates = matrix_rows.map { |row| [ row[:channel], row[:product_name], row[:style_name] ] }.uniq
      return 0 if supported_templates.empty?

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
        product.description = "Imported from #{source_filename} by #{imported_by.email}"
        product.base_price = 0
        product.pricing_mode = :per_unit
        product.active = true
        product.product_type = product_type
        product.style_name = style_name
        product.pricing_channel = channel
        product.save!
        updates += 1
      end

      deactivate_unsupported_templates!(supported_templates)
      updates
    end

    def deactivate_unsupported_templates!(supported_templates)
      supported_lookup = supported_templates.to_set

      Product.where("sku LIKE 'PB-%'").find_each do |product|
        key = [ product.pricing_channel.to_s, product.product_type.to_s, product.style_name.to_s ]
        next if supported_lookup.include?(key)
        next unless product.pricing_channel.present? && product.product_type.present? && product.style_name.present?
        next unless product.active?

        product.update!(active: false)
      end
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
      combos = rows.map { |row| [ row[:channel], row[:product_name], row[:style_name] ] }.uniq
      combos.each do |channel, product_name, style_name|
        PriceMatrixEntry.where(channel: channel, product_name: product_name, style_name: style_name).delete_all
      end

      return if rows.empty?

      timestamp = Time.current
      payload = rows.map do |row|
        row.merge(created_at: timestamp, updated_at: timestamp)
      end

      PriceMatrixEntry.upsert_all(payload, unique_by: :index_price_matrix_entries_on_lookup_key)
    end

    def build_track_tier_rows(sheet, track_codes)
      base_tiers = []
      previous_max = -1

      TRACK_ROWS_RANGE.each do |row_idx|
        max_width = integer_cell(sheet, row_idx, TRACK_MAX_WIDTH_COL)
        price = decimal_cell(sheet, row_idx, TRACK_PRICE_COL)
        next if max_width.nil? || price.nil?

        min_width = previous_max + 1
        base_tiers << { min: min_width, max: max_width, price: price }
        previous_max = max_width
      end

      tier_codes = (track_codes + [ "shared" ]).uniq
      rows = []
      tier_codes.each do |track_name|
        base_tiers.each do |tier|
          rows << {
            track_name: track_name,
            width_band_min_mm: tier[:min],
            width_band_max_mm: tier[:max],
            price: tier[:price],
            currency: "AUD",
            source_version: source_filename
          }
        end
      end

      rows
    end

    def replace_track_price_tiers!(rows)
      names = rows.map { |row| row[:track_name] }.uniq
      TrackPriceTier.where(track_name: names).delete_all if names.any?
      return if rows.empty?

      timestamp = Time.current
      payload = rows.map do |row|
        row.merge(created_at: timestamp, updated_at: timestamp)
      end

      TrackPriceTier.upsert_all(payload, unique_by: :index_track_price_tiers_on_lookup_key)
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
