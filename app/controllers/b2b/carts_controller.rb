class B2b::CartsController < B2b::BaseController
  before_action :load_cart

  def show
    @cart_warnings, @cart_errors = recalculate_cart_lines!
    @cart_total = @cart.total
  end

  def add_line
    product = Product.active.find_by(id: add_line_params[:product_id])
    if product.blank?
      redirect_back fallback_location: b2b_shop_path, alert: "Selected product is not available."
      return
    end

    result = Orders::CartLineBuilder.new(
      customer_mode: :b2b,
      product: product,
      attributes: add_line_params.except(:product_id)
    ).build

    if result.error.present?
      redirect_back fallback_location: b2b_shop_product_path(product), alert: result.error
      return
    end

    @cart.add_line(result.line)
    notice_message = "Item added to cart."
    notice_message = "#{notice_message} #{result.warning}" if result.warning.present?
    redirect_to b2b_cart_path, notice: notice_message
  end

  def update_line
    existing_line = @cart.lines.find { |line| line["id"].to_s == params[:line_id].to_s }
    if existing_line.blank?
      redirect_to b2b_cart_path, alert: "Cart line not found."
      return
    end

    product = Product.active.find_by(id: existing_line["product_id"])
    if product.blank?
      @cart.remove_line(existing_line["id"])
      redirect_to b2b_cart_path, alert: "Product is no longer available and was removed from cart."
      return
    end

    attributes = existing_line.merge(update_line_params.to_h)
    result = Orders::CartLineBuilder.new(
      customer_mode: :b2b,
      product: product,
      attributes: attributes,
      line_id: existing_line["id"]
    ).build

    if result.error.present?
      redirect_to b2b_cart_path, alert: result.error
      return
    end

    @cart.replace_line(existing_line["id"], result.line)
    notice_message = "Cart line updated."
    notice_message = "#{notice_message} #{result.warning}" if result.warning.present?
    redirect_to b2b_cart_path, notice: notice_message
  end

  def remove_line
    if @cart.remove_line(params[:line_id])
      redirect_to b2b_cart_path, notice: "Cart line removed."
    else
      redirect_to b2b_cart_path, alert: "Cart line not found."
    end
  end

  def checkout
    warnings, errors = recalculate_cart_lines!
    if @cart.empty?
      redirect_to b2b_cart_path, alert: "Your cart is empty."
      return
    end

    if errors.any?
      redirect_to b2b_cart_path, alert: errors.join(" ")
      return
    end

    quote_request = build_quote_request_from_cart

    begin
      ActiveRecord::Base.transaction do
        quote_request.save!
        Inventory::StockDeductor.new(quote_request: quote_request).deduct!
      end
    rescue ActiveRecord::RecordInvalid, ArgumentError => e
      redirect_to b2b_cart_path, alert: e.message
      return
    end

    notice_message = "Order submitted successfully."
    notice_message = "#{notice_message} #{warnings.join(' ')}" if warnings.any?
    notice_message = append_email_result(notice_message, quote_request)
    @cart.clear

    redirect_to quote_request_path(quote_request), notice: notice_message
  end

  private

  def load_cart
    @cart = Orders::SessionCart.new(session: session)
  end

  def add_line_params
    params.require(:line).permit(
      :product_id,
      :location_name,
      :description,
      :width_mm,
      :ceiling_drop_mm,
      :finished_floor_mode,
      :opening_type,
      :opening_code,
      :track_selected,
      :fixing,
      :quantity,
      :wand_required,
      :wand_quantity,
      :end_cap_quantity,
      :stopper_quantity,
      :wand_hook_quantity,
      :width_notes,
      :material_name,
      :material_number,
      :lv_name,
      :high_temp_custom
    )
  end

  def update_line_params
    params.require(:line).permit(
      :quantity,
      :wand_required,
      :wand_quantity,
      :end_cap_quantity,
      :stopper_quantity,
      :wand_hook_quantity,
      :track_selected,
      :opening_type,
      :finished_floor_mode,
      :fixing
    )
  end

  def checkout_params
    params.fetch(:checkout, {}).permit(
      :customer_reference,
      :pickup_method,
      :delivery_address,
      :billing_address,
      :notes
    )
  end

  def recalculate_cart_lines!
    warnings = []
    errors = []
    recalculated_lines = []

    @cart.lines.each_with_index do |line, index|
      product = Product.active.find_by(id: line["product_id"])
      if product.blank?
        errors << "Line #{index + 1}: product is no longer available."
        next
      end

      result = Orders::CartLineBuilder.new(
        customer_mode: :b2b,
        product: product,
        attributes: line,
        line_id: line["id"]
      ).build

      if result.error.present?
        errors << "Line #{index + 1}: #{result.error}"
        next
      end

      recalculated_lines << result.line
      warnings << "Line #{index + 1}: #{result.warning}" if result.warning.present?
    end

    @cart.replace_lines(recalculated_lines)
    [ warnings, errors ]
  end

  def build_quote_request_from_cart
    order_params = checkout_params
    pickup_method = QuoteRequest.pickup_methods.key?(order_params[:pickup_method].to_s) ? order_params[:pickup_method] : "delivery"

    quote_request = current_user.quote_requests.new(
      customer_mode: :b2b,
      customer_name: current_user.email,
      customer_email: current_user.email,
      customer_reference: order_params[:customer_reference],
      pickup_method: pickup_method,
      delivery_address: order_params[:delivery_address],
      billing_address: order_params[:billing_address],
      notes: order_params[:notes].presence || "Charge to account",
      status: :order_processing,
      submitted_at: Time.current,
      valid_until: 14.days.from_now.to_date
    )

    @cart.lines.each_with_index do |line, index|
      product = Product.find(line["product_id"])

      quote_request.quote_items.build(
        product: product,
        line_position: index + 1,
        description: line["description"],
        quantity: line["quantity"].to_i,
        area_sqm: line["area_sqm"].to_d,
        unit_price: line["unit_price"].to_d,
        line_total: line["line_total"].to_d,
        applied_rule_names: "Matrix pricing",
        width: (line["width_mm"].to_d / 10).round(2),
        height: (line["ceiling_drop_mm"].to_d / 10).round(2),
        location_name: line["location_name"],
        track_selected: line["track_selected"],
        fixing: line["fixing"],
        opening_type: line["opening_type"],
        opening_code: line["opening_code"],
        width_mm: line["width_mm"].to_i,
        ceiling_drop_mm: line["ceiling_drop_mm"].to_i,
        finished_floor_mode: line["finished_floor_mode"],
        factory_drop_mm: line["factory_drop_mm"].to_i,
        material_name: line["material_name"],
        material_number: line["material_number"],
        lv_name: line["lv_name"],
        high_temp_custom: line["high_temp_custom"],
        width_notes: line["width_notes"],
        wand_required: ActiveModel::Type::Boolean.new.cast(line["wand_required"]),
        wand_quantity: line["wand_quantity"].to_i,
        end_cap_quantity: line["end_cap_quantity"].to_i,
        stopper_quantity: line["stopper_quantity"].to_i,
        wand_hook_quantity: line["wand_hook_quantity"].to_i,
        curtain_price: line["curtain_price"].to_d,
        track_price: line["track_price"].to_d,
        hooks_display: line["hooks_display"],
        hooks_total: line["hooks_total"].to_i,
        brackets_total: line["brackets_total"].to_i,
        track_metres_required: line["track_metres_required"].to_i
      )
    end

    quote_request
  end

  def append_email_result(notice_message, quote_request)
    begin
      QuoteRequestMailer.customer_order_invoice(quote_request).deliver_now
      QuoteRequestMailer.internal_order_notification(quote_request).deliver_now
      notice_message
    rescue StandardError => e
      Rails.logger.error("Order email delivery failed for QuoteRequest ##{quote_request.id}: #{e.class} - #{e.message}")
      "#{notice_message} Email delivery failed."
    end
  end
end
