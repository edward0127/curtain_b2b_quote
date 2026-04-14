require "bigdecimal"
require "bigdecimal/util"

module Pricing
  class MatrixCalculator
    Result = Struct.new(:curtain_price, :track_price, :line_total, keyword_init: true)

    def initialize(customer_mode:, product:, width_mm:, drop_mm:)
      @customer_mode = customer_mode.to_s
      @product = product
      @width_mm = width_mm.to_i
      @drop_mm = drop_mm.to_i
    end

    def calculate
      curtain_price = selected_matrix_entry&.price.to_d || 0.to_d

      Result.new(
        curtain_price: curtain_price.round(2),
        track_price: 0.to_d,
        line_total: curtain_price.round(2)
      )
    end

    private

    attr_reader :customer_mode, :product, :width_mm, :drop_mm

    def selected_matrix_entry
      base_scope = PriceMatrixEntry.where(channel: normalized_channel, product_name: normalized_product_name)
      base_scope = base_scope.where("width_band_min_mm <= ? AND width_band_max_mm >= ?", width_mm, width_mm)
      base_scope = base_scope.where("drop_band_min_mm <= ? AND drop_band_max_mm >= ?", drop_mm, drop_mm)

      style_scope = base_scope.where(style_name: normalized_style_name)
      style_scope.first || base_scope.where(style_name: "").first || base_scope.first
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
