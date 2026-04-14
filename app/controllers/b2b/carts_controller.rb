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
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
    Rails.logger.error("B2B cart add_line failed for user ##{current_user.id}: #{e.class} - #{e.message}")
    redirect_back fallback_location: b2b_shop_path, alert: "Could not update your cart. Please try again."
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

    quote_request = @cart.quote_request
    if quote_request.blank?
      redirect_to b2b_cart_path, alert: "Could not load your cart. Please add items again."
      return
    end

    apply_checkout_details!(quote_request)

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
    @cart = Orders::SessionCart.new(session: session, user: current_user)
  rescue StandardError => e
    Rails.logger.error("B2B cart load failed for user ##{current_user.id}: #{e.class} - #{e.message}")
    session.delete(Orders::SessionCart::SESSION_KEY)
    session.delete("orders_v2_b2b_cart")
    @cart = Orders::SessionCart.new(session: session, user: current_user)
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

  def apply_checkout_details!(quote_request)
    order_params = checkout_params
    pickup_method = QuoteRequest.pickup_methods.key?(order_params[:pickup_method].to_s) ? order_params[:pickup_method] : "delivery"

    quote_request.assign_attributes(
      customer_mode: :b2b,
      customer_name: current_user.email,
      customer_email: current_user.email,
      customer_reference: order_params[:customer_reference],
      pickup_method: pickup_method,
      delivery_address: order_params[:delivery_address],
      billing_address: order_params[:billing_address],
      notes: order_params[:notes].presence || "Charge to account",
      status: :order_processing,
      submitted_at: quote_request.submitted_at || Time.current,
      valid_until: quote_request.valid_until || 14.days.from_now.to_date
    )
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
