require "bigdecimal"
require "bigdecimal/util"

module Pricing
  class MatrixCalculator
    Result = Struct.new(:curtain_price, :track_price, :line_total, keyword_init: true)

    def initialize(customer_mode:, product:, width_mm:, drop_mm:, track_selected:)
      @customer_mode = customer_mode.to_s
      @product = product
      @width_mm = width_mm.to_i
      @drop_mm = drop_mm.to_i
      @track_selected = track_selected.to_s.strip
    end

    def calculate
      curtain_price = selected_matrix_entry&.price.to_d || 0.to_d
      track_price = selected_track_tier&.price.to_d || 0.to_d

      Result.new(
        curtain_price: curtain_price.round(2),
        track_price: track_price.round(2),
        line_total: (curtain_price + track_price).round(2)
      )
    end

    private

    attr_reader :customer_mode, :product, :width_mm, :drop_mm, :track_selected

    def selected_matrix_entry
      base_scope = PriceMatrixEntry.where(channel: normalized_channel, product_name: normalized_product_name)
      base_scope = base_scope.where("width_band_min_mm <= ? AND width_band_max_mm >= ?", width_mm, width_mm)
      base_scope = base_scope.where("drop_band_min_mm <= ? AND drop_band_max_mm >= ?", drop_mm, drop_mm)

      style_scope = base_scope.where(style_name: normalized_style_name)
      style_scope.first || base_scope.where(style_name: "").first || base_scope.first
    end

    def selected_track_tier
      return nil if no_track_selected?

      scope = TrackPriceTier.where("width_band_min_mm <= ? AND width_band_max_mm >= ?", width_mm, width_mm)
      selected_code = normalized_track_selected
      return scope.where(track_name: selected_code).first if scope.where(track_name: selected_code).exists?

      scope.where(track_name: "shared").first || scope.first
    end

    def no_track_selected?
      track_selected.casecmp("none").zero?
    end

    def normalized_track_selected
      return "shared" if track_selected.blank?

      track_selected
    end

    def normalized_channel
      customer_mode == "b2c" ? "b2c" : "b2b"
    end

    def normalized_product_name
      if product.respond_to?(:product_type) && product.product_type.present?
        product.product_type.to_s
      else
        product.name.to_s.split(" (").first
      end
    end

    def normalized_style_name
      return product.style_name.to_s if product.respond_to?(:style_name) && product.style_name.present?

      "S Wave"
    end
  end
end
