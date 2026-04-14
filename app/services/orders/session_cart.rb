module Orders
  class SessionCart
    SESSION_KEY = "orders_v2_b2b_cart_id".freeze
    LEGACY_SESSION_KEYS = [ "orders_v2_b2b_cart" ].freeze

    def initialize(session:, user:)
      @session = session
      @user = user
      cleanup_legacy_payload!
      @quote_request = load_quote_request
    end

    def lines
      return [] if quote_request.blank?

      quote_request.quote_items.ordered.includes(:product).map { |item| line_hash(item) }
    end

    def empty?
      lines.empty?
    end

    def total
      lines.sum { |line| line.fetch("line_total", 0).to_d }.round(2)
    end

    def quote_request
      @quote_request
    end

    def add_line(line_hash)
      line = stringify_keys(line_hash)

      if quote_request.blank?
        @quote_request = build_cart_quote_request_with_first_line(line)
      else
        quote_request.quote_items.create!(quote_item_attributes(line).merge(line_position: next_line_position))
        quote_request.touch
      end

      persist_reference!
    end

    def replace_line(line_id, line_hash)
      return false if quote_request.blank?

      line_item = quote_request.quote_items.find_by(id: line_id)
      return false if line_item.blank?

      line_item.update!(quote_item_attributes(stringify_keys(line_hash)).merge(line_position: line_item.line_position))
      quote_request.touch
      true
    end

    def remove_line(line_id)
      return false if quote_request.blank?

      line_item = quote_request.quote_items.find_by(id: line_id)
      return false if line_item.blank?

      line_item.destroy!
      cleanup_empty_quote_request!
      true
    end

    def clear
      clear_reference!
    end

    def replace_lines(new_lines)
      new_lines = Array(new_lines).map { |line| stringify_keys(line) }

      if new_lines.empty?
        if quote_request.present?
          quote_request.quote_items.destroy_all
          cleanup_empty_quote_request!
        end
        return
      end

      if quote_request.blank?
        @quote_request = build_cart_quote_request_with_first_line(new_lines.first)
        new_lines.drop(1).each do |line|
          quote_request.quote_items.create!(quote_item_attributes(line).merge(line_position: next_line_position))
        end
        persist_reference!
        return
      end

      existing_items = quote_request.quote_items.index_by { |item| item.id.to_s }
      kept_ids = []

      new_lines.each_with_index do |line, index|
        item = existing_items[line["id"].to_s]
        attrs = quote_item_attributes(line).merge(line_position: index + 1)

        if item.present?
          item.update!(attrs)
          kept_ids << item.id
        else
          created = quote_request.quote_items.create!(attrs)
          kept_ids << created.id
        end
      end

      quote_request.quote_items.where.not(id: kept_ids).destroy_all
      cleanup_empty_quote_request!
      quote_request.touch if quote_request.present?
      persist_reference!
    end

    def cleanup_legacy_payload!
      LEGACY_SESSION_KEYS.each { |key| session.delete(key) }
    end

    private

    attr_reader :session, :user

    def load_quote_request
      scope = user.quote_requests.where(customer_mode: :b2b, status: :order_processing, submitted_at: nil).includes(quote_items: :product)

      referenced = scope.find_by(id: session[SESSION_KEY]) if session[SESSION_KEY].present?
      current = referenced || scope.order(updated_at: :desc).first

      if current.present?
        session[SESSION_KEY] = current.id
      else
        clear_reference!
      end

      current
    end

    def persist_reference!
      if quote_request.present?
        session[SESSION_KEY] = quote_request.id
      else
        clear_reference!
      end
    end

    def clear_reference!
      session.delete(SESSION_KEY)
    end

    def build_cart_quote_request_with_first_line(line)
      quote_request = user.quote_requests.new(
        customer_mode: :b2b,
        customer_name: user.email,
        customer_email: user.email,
        pickup_method: :delivery,
        status: :order_processing,
        submitted_at: nil,
        valid_until: 14.days.from_now.to_date,
        notes: ""
      )
      quote_request.quote_items.build(quote_item_attributes(line).merge(line_position: 1))
      quote_request.save!
      quote_request
    end

    def cleanup_empty_quote_request!
      return if quote_request.blank?
      return if quote_request.quote_items.exists?

      quote_request.destroy!
      @quote_request = nil
      clear_reference!
    end

    def next_line_position
      (quote_request.quote_items.maximum(:line_position) || 0) + 1
    end

    def line_hash(item)
      {
        "id" => item.id.to_s,
        "product_id" => item.product_id,
        "product_name" => item.product&.name.to_s,
        "location_name" => item.location_name.to_s,
        "description" => item.description.to_s,
        "width_mm" => item.width_mm.to_i,
        "ceiling_drop_mm" => item.ceiling_drop_mm.to_i,
        "finished_floor_mode" => item.finished_floor_mode.to_s,
        "opening_type" => item.opening_type.to_s,
        "opening_code" => item.opening_code.to_s,
        "track_selected" => item.track_selected.to_s,
        "fixing" => item.fixing.to_s,
        "width_notes" => item.width_notes.to_s,
        "material_name" => item.material_name.to_s,
        "material_number" => item.material_number.to_s,
        "lv_name" => item.lv_name.to_s,
        "high_temp_custom" => item.high_temp_custom.to_s,
        "quantity" => item.quantity.to_i,
        "wand_required" => item.wand_required,
        "wand_quantity" => item.wand_quantity.to_i,
        "end_cap_quantity" => item.end_cap_quantity.to_i,
        "stopper_quantity" => item.stopper_quantity.to_i,
        "wand_hook_quantity" => item.wand_hook_quantity.to_i,
        "factory_drop_mm" => item.factory_drop_mm.to_i,
        "hooks_display" => item.hooks_display.to_s,
        "hooks_total" => item.hooks_total.to_i,
        "brackets_total" => item.brackets_total.to_i,
        "track_metres_required" => item.track_metres_required.to_i,
        "curtain_price" => item.curtain_price.to_d.to_s("F"),
        "track_price" => item.track_price.to_d.to_s("F"),
        "unit_price" => item.unit_price.to_d.to_s("F"),
        "line_total" => item.line_total.to_d.to_s("F"),
        "area_sqm" => item.area_sqm.to_d.to_s("F")
      }
    end

    def quote_item_attributes(line)
      width_mm = line.fetch("width_mm", 0).to_i
      ceiling_drop_mm = line.fetch("ceiling_drop_mm", 0).to_i
      opening_type = line.fetch("opening_type", "").to_s
      finished_floor_mode = line.fetch("finished_floor_mode", "").to_s

      {
        product_id: line.fetch("product_id").to_i,
        description: line["description"],
        quantity: [ line.fetch("quantity", 1).to_i, 1 ].max,
        area_sqm: line.fetch("area_sqm", 0).to_d,
        unit_price: line.fetch("unit_price", 0).to_d,
        line_total: line.fetch("line_total", 0).to_d,
        applied_rule_names: "Matrix pricing",
        width: (width_mm.to_d / 10).round(2),
        height: (ceiling_drop_mm.to_d / 10).round(2),
        location_name: line["location_name"],
        track_selected: line["track_selected"].presence,
        fixing: line["fixing"],
        opening_type: QuoteItem.opening_types.key?(opening_type) ? opening_type : "single_open",
        opening_code: line["opening_code"],
        width_mm: width_mm,
        ceiling_drop_mm: ceiling_drop_mm,
        finished_floor_mode: QuoteItem.finished_floor_modes.key?(finished_floor_mode) ? finished_floor_mode : "just_off_floor",
        factory_drop_mm: line.fetch("factory_drop_mm", 0).to_i,
        material_name: line["material_name"],
        material_number: line["material_number"],
        lv_name: line["lv_name"],
        high_temp_custom: line["high_temp_custom"],
        width_notes: line["width_notes"],
        wand_required: ActiveModel::Type::Boolean.new.cast(line["wand_required"]),
        wand_quantity: [ line.fetch("wand_quantity", 0).to_i, 0 ].max,
        end_cap_quantity: [ line.fetch("end_cap_quantity", 0).to_i, 0 ].max,
        stopper_quantity: [ line.fetch("stopper_quantity", 0).to_i, 0 ].max,
        wand_hook_quantity: [ line.fetch("wand_hook_quantity", 0).to_i, 0 ].max,
        curtain_price: line.fetch("curtain_price", 0).to_d,
        track_price: line.fetch("track_price", 0).to_d,
        hooks_display: line["hooks_display"],
        hooks_total: [ line.fetch("hooks_total", 0).to_i, 0 ].max,
        brackets_total: [ line.fetch("brackets_total", 0).to_i, 0 ].max,
        track_metres_required: [ line.fetch("track_metres_required", 0).to_i, 0 ].max
      }
    end

    def stringify_keys(value)
      return value unless value.is_a?(Hash)

      value.each_with_object({}) do |(key, item), memo|
        memo[key.to_s] = item
      end
    end
  end
end
