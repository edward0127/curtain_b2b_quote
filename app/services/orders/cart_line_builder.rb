module Orders
  class CartLineBuilder
    Result = Struct.new(:line, :warning, :error, keyword_init: true)

    def initialize(customer_mode:, product:, attributes:, line_id: nil)
      @customer_mode = customer_mode.to_s
      @product = product
      @attributes = attributes.to_h
      @line_id = line_id.presence || SecureRandom.uuid
    end

    def build
      return Result.new(error: "Product is required.") if product.blank?
      return Result.new(error: "Width and drop must be greater than 0.") if width_mm <= 0 || ceiling_drop_mm <= 0

      requirements = Inventory::RequirementCalculator.new(
        width_mm: width_mm,
        opening_type: opening_type,
        ceiling_drop_mm: ceiling_drop_mm,
        finished_floor_mode: finished_floor_mode,
        track_selected: track_selected
      ).calculate

      max_quantity = Inventory::MaxQuantityCalculator.new(
        product: product,
        requirement_per_unit: requirement_per_unit(requirements),
        requested_quantity: requested_quantity
      ).calculate

      if max_quantity.max_quantity <= 0
        return Result.new(error: "Insufficient stock for #{product.name}.")
      end

      pricing = Pricing::MatrixCalculator.new(
        customer_mode: customer_mode,
        product: product,
        width_mm: width_mm,
        drop_mm: ceiling_drop_mm,
        track_selected: track_selected
      ).calculate
      if pricing.curtain_price.to_d <= 0
        return Result.new(error: "No matrix price is available for this product and size.")
      end

      final_quantity = max_quantity.adjusted_quantity
      warning = if max_quantity.adjusted
        "Quantity adjusted from #{requested_quantity} to #{final_quantity} (#{max_quantity.limiting_component})."
      end

      Result.new(
        line: {
          "id" => line_id,
          "product_id" => product.id,
          "product_name" => product.name,
          "location_name" => cleaned_string(:location_name),
          "description" => cleaned_string(:description).presence || [ cleaned_string(:location_name).presence, product.name ].compact.join(" - "),
          "width_mm" => width_mm,
          "ceiling_drop_mm" => ceiling_drop_mm,
          "finished_floor_mode" => finished_floor_mode,
          "opening_type" => opening_type,
          "opening_code" => cleaned_string(:opening_code),
          "track_selected" => track_selected,
          "fixing" => fixing,
          "width_notes" => cleaned_string(:width_notes),
          "material_name" => cleaned_string(:material_name),
          "material_number" => cleaned_string(:material_number),
          "lv_name" => cleaned_string(:lv_name),
          "high_temp_custom" => cleaned_string(:high_temp_custom),
          "quantity" => final_quantity,
          "wand_required" => wand_required?,
          "wand_quantity" => accessory_quantity(:wand_quantity),
          "end_cap_quantity" => accessory_quantity(:end_cap_quantity),
          "stopper_quantity" => accessory_quantity(:stopper_quantity),
          "wand_hook_quantity" => accessory_quantity(:wand_hook_quantity),
          "factory_drop_mm" => requirements.factory_drop_mm,
          "hooks_display" => requirements.hooks_display,
          "hooks_total" => requirements.hooks_total,
          "brackets_total" => requirements.brackets_total,
          "track_metres_required" => requirements.track_metres_required,
          "curtain_price" => pricing.curtain_price.to_d.round(2).to_s("F"),
          "track_price" => pricing.track_price.to_d.round(2).to_s("F"),
          "unit_price" => pricing.line_total.to_d.round(2).to_s("F"),
          "line_total" => (pricing.line_total.to_d * final_quantity).round(2).to_s("F"),
          "area_sqm" => ((width_mm.to_d * ceiling_drop_mm.to_d) / 1_000_000).round(3).to_s("F")
        },
        warning: warning
      )
    end

    private

    attr_reader :customer_mode, :product, :attributes, :line_id

    def width_mm
      attributes.fetch("width_mm", 0).to_i
    end

    def ceiling_drop_mm
      attributes.fetch("ceiling_drop_mm", 0).to_i
    end

    def requested_quantity
      [ attributes.fetch("quantity", 1).to_i, 1 ].max
    end

    def opening_type
      raw = cleaned_string(:opening_type)
      QuoteItem.opening_types.key?(raw) ? raw : "single_open"
    end

    def finished_floor_mode
      raw = cleaned_string(:finished_floor_mode)
      QuoteItem.finished_floor_modes.key?(raw) ? raw : "just_off_floor"
    end

    def track_selected
      selected = cleaned_string(:track_selected)
      return "shared" if selected.blank?
      return "none" if selected.casecmp("none").zero?

      selected
    end

    def fixing
      raw = cleaned_string(:fixing).upcase
      %w[FF TF].include?(raw) ? raw : "TF"
    end

    def accessory_quantity(key)
      [ attributes.fetch(key.to_s, 0).to_i, 0 ].max
    end

    def requirement_per_unit(requirements)
      {
        track_metres_required: requirements.track_metres_required,
        hooks_total: requirements.hooks_total,
        brackets_total: requirements.brackets_total,
        wand_quantity: accessory_quantity(:wand_quantity),
        end_cap_quantity: accessory_quantity(:end_cap_quantity),
        stopper_quantity: accessory_quantity(:stopper_quantity),
        wand_hook_quantity: accessory_quantity(:wand_hook_quantity)
      }
    end

    def wand_required?
      accessory_quantity(:wand_quantity).positive? || truthy?(attributes.fetch("wand_required", false))
    end

    def truthy?(value)
      %w[1 true yes y on].include?(value.to_s.strip.downcase)
    end

    def cleaned_string(key)
      attributes.fetch(key.to_s, "").to_s.strip
    end
  end
end
