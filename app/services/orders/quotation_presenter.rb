module Orders
  class QuotationPresenter
    ACCESSORY_FIELDS = {
      wand_quantity: "Wands",
      end_cap_quantity: "End Caps",
      stopper_quantity: "Stoppers",
      wand_hook_quantity: "Wand Hooks"
    }.freeze

    def initialize(quote_request)
      @quote_request = quote_request
      @app_setting = AppSetting.current
    end

    def order_number
      quote_request.quote_number
    end

    def order_date
      quote_request.submitted_at || quote_request.created_at
    end

    def customer_name
      quote_request.customer_name.presence || quote_request.user.email
    end

    def company_name
      quote_request.company_name.presence
    end

    def customer_email
      quote_request.customer_email.presence || quote_request.user.email
    end

    def customer_phone
      quote_request.customer_phone.presence
    end

    def delivery_address
      quote_request.delivery_address.presence
    end

    def pickup_method
      quote_request.pickup_method&.humanize
    end

    def rows
      @rows ||= quote_request.quote_items.flat_map do |item|
        [ primary_row_for(item) ] + accessory_rows_for(item)
      end
    end

    def total_ex_gst
      rows.sum { |row| row[:total].to_d }.round(2)
    end

    def gst
      (total_ex_gst * BigDecimal("0.1")).round(2)
    end

    def total_inc_gst
      (total_ex_gst + gst).round(2)
    end

    def bank_details
      {
        account_name: setting_or_env(:bank_account_name, "BANK_ACCOUNT_NAME"),
        bank_name: setting_or_env(:bank_name, "BANK_NAME"),
        bsb: setting_or_env(:bank_bsb, "BANK_BSB"),
        account_number: setting_or_env(:bank_account_number, "BANK_ACCOUNT_NUMBER")
      }
    end

    private

    attr_reader :quote_request, :app_setting

    def primary_row_for(item)
      {
        location: item.location_name.presence || "-",
        description: line_description(item),
        opening: item.opening_code.presence || "-",
        track: track_code(item),
        total: item.line_total.to_d
      }
    end

    def accessory_rows_for(item)
      ACCESSORY_FIELDS.each_with_object([]) do |(field, label), rows|
        quantity = item.public_send(field).to_i
        next if quantity <= 0

        rows << {
          location: item.location_name.presence || "-",
          description: "#{label} x #{quantity}",
          opening: "",
          track: "",
          total: 0.to_d
        }
      end
    end

    def line_description(item)
      base = item.product.product_type.presence || item.product.name
      style = item.product.style_name.presence
      [ base, style ].compact.join(" - ")
    end

    def track_code(item)
      track = item.track_selected.to_s.strip
      return "" if track.blank? || track.casecmp("none").zero?

      track
    end

    def setting_or_env(setting_key, env_key)
      if app_setting.respond_to?(setting_key)
        value = app_setting.public_send(setting_key).to_s.strip
        return value if value.present?
      end

      env_value = ENV.fetch(env_key, "").to_s.strip
      return env_value if env_value.present?

      "Not configured"
    end
  end
end
