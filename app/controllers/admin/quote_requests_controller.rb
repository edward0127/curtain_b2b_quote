class Admin::QuoteRequestsController < ApplicationController
  DEFAULT_ORDER_LINE_COUNT = 6
  MAX_ORDER_LINE_COUNT = 25

  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_quote_request, only: %i[ show update update_status document invoice to_chinese_factory ]
  before_action :load_order_builder_collections, only: %i[ new create ]

  def index
    allowed_statuses = QuoteRequest::ORDER_WORKFLOW_STATUSES
    @status_filter = params[:status].presence
    @status_filter = nil unless allowed_statuses.include?(@status_filter)

    @quote_requests = QuoteRequest.includes(:user, quote_items: :product)
      .recent_first
      .where(status: allowed_statuses)
      .where.not(submitted_at: nil)
    @quote_requests = @quote_requests.where(status: @status_filter) if @status_filter.present?
  end

  def new
    @quote_request = QuoteRequest.new(
      customer_mode: :b2c,
      pickup_method: :delivery,
      valid_until: 14.days.from_now.to_date
    )
    build_order_items(@quote_request)
  end

  def create
    if b2b_mode_requested_from_admin_form?
      @quote_request = QuoteRequest.new(order_header_params.merge(customer_mode: :b2c))
      @quote_request.errors.add(:base, "Admin order builder only supports B2C orders.")
      build_order_items(@quote_request)
      render :new, status: :unprocessable_entity
      return
    end

    @warnings = []
    @quote_request = QuoteRequest.new(order_header_params.merge(customer_mode: :b2c))
    assign_order_customer!(@quote_request)
    @quote_request.created_by_user = current_user
    @quote_request.status = :order_processing
    @quote_request.submitted_at = Time.current

    build_order_line_items!(@quote_request, warnings: @warnings)

    if @quote_request.errors.any?
      build_order_items(@quote_request)
      render :new, status: :unprocessable_entity
      return
    end

    begin
      ActiveRecord::Base.transaction do
        @quote_request.save!
        Inventory::StockDeductor.new(quote_request: @quote_request).deduct!
      end
    rescue ActiveRecord::RecordInvalid, ArgumentError => e
      @quote_request.errors.add(:base, e.message)
      build_order_items(@quote_request)
      render :new, status: :unprocessable_entity
      return
    end

    notice_message = "Order submitted successfully."
    notice_message += " #{@warnings.join(' ')}" if @warnings.any?

    begin
      QuoteRequestMailer.customer_order_invoice(@quote_request).deliver_now
      QuoteRequestMailer.internal_order_notification(@quote_request).deliver_now
    rescue StandardError => e
      Rails.logger.error("Order email delivery failed for QuoteRequest ##{@quote_request.id}: #{e.class} - #{e.message}")
      notice_message = "#{notice_message} Email delivery failed."
    end

    redirect_to admin_quote_request_path(@quote_request), notice: notice_message
  end

  def show
  end

  def update
    if @quote_request.update(admin_quote_request_params)
      redirect_to admin_quote_request_path(@quote_request), notice: "Order details updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def update_status
    target_status = params[:status].to_s
    if target_status == @quote_request.status
      redirect_to admin_quote_request_path(@quote_request), notice: "Status is already #{@quote_request.display_status}."
      return
    end

    previous_status = @quote_request.status
    if order_workflow_status_change?(target_status)
      @quote_request.update_order_status!(target_status)
    else
      @quote_request.transition_to!(target_status)
    end

    send_pickup_ready_email_if_needed(previous_status: previous_status, target_status: target_status)
    redirect_to admin_quote_request_path(@quote_request), notice: "Status updated to #{@quote_request.display_status}."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to admin_quote_request_path(@quote_request), alert: e.message
  end

  def document
    respond_to do |format|
      format.html { render template: "quote_requests/document" }
      format.pdf do
        pdf_bytes = QuotePdfRenderer.new(@quote_request).render
        send_data(
          pdf_bytes,
          filename: "#{@quote_request.quote_number}.pdf",
          type: "application/pdf",
          disposition: "attachment"
        )
      end
    end
  end

  def invoice
    pdf_bytes = InvoicePdfRenderer.new(@quote_request).render
    send_data(
      pdf_bytes,
      filename: "Invoice-#{@quote_request.quote_number}.pdf",
      type: "application/pdf",
      disposition: "attachment"
    )
  end

  def to_chinese_factory
    respond_to do |format|
      format.html
      format.pdf do
        pdf_bytes = FactorySheetPdfRenderer.new(@quote_request).render
        send_data(
          pdf_bytes,
          filename: "Factory-#{@quote_request.quote_number}.pdf",
          type: "application/pdf",
          disposition: "attachment"
        )
      end
    end
  end

  private

  def set_quote_request
    @quote_request = QuoteRequest.includes(:user, quote_items: :product).find(params[:id])
  end

  def admin_quote_request_params
    params.require(:quote_request).permit(:customer_reference, :valid_until, :notes)
  end

  def order_header_params
    params.require(:quote_request).permit(
      :customer_mode,
      :customer_reference,
      :valid_until,
      :notes,
      :customer_name,
      :company_name,
      :customer_email,
      :customer_phone,
      :delivery_address,
      :billing_address,
      :pickup_method
    )
  end

  def load_order_builder_collections
    @products = Product.orderable_for_channel("b2c")
    @track_codes = available_track_codes
  end

  def build_order_items(quote_request)
    existing_count = quote_request.quote_items.reject(&:marked_for_destruction?).size
    target_count = [ existing_count, requested_order_line_count ].max

    (target_count - existing_count).times do |offset|
      quote_request.quote_items.build(
        line_position: existing_count + offset + 1,
        quantity: 1,
        opening_type: :single_open,
        finished_floor_mode: :just_off_floor,
        track_selected: "shared"
      )
    end
  end

  def requested_order_line_count
    requested = params[:line_count].to_i
    requested = DEFAULT_ORDER_LINE_COUNT if requested <= 0
    [ requested, MAX_ORDER_LINE_COUNT ].min
  end

  def assign_order_customer!(quote_request)
    quote_request.customer_mode = :b2c
    quote_request.user = current_user
    quote_request.errors.add(:customer_name, "can't be blank") if quote_request.customer_name.blank?
    quote_request.errors.add(:customer_email, "can't be blank") if quote_request.customer_email.blank?
  end

  def b2b_mode_requested_from_admin_form?
    params.dig(:quote_request, :customer_mode).to_s == "b2b"
  end

  def build_order_line_items!(quote_request, warnings:)
    line_attributes = params.dig(:quote_request, :quote_items_attributes) || {}
    next_position = 1

    line_attributes.values.each do |raw_attrs|
      attrs = raw_attrs.respond_to?(:to_unsafe_h) ? raw_attrs.to_unsafe_h : raw_attrs.to_h
      next if order_line_blank?(attrs)

      product = Product.find_by(id: attrs["product_id"])
      if product.blank?
        quote_request.errors.add(:base, "Line #{next_position}: product is required.")
        next
      end
      if product.pricing_channel.to_s != "b2c"
        quote_request.errors.add(:base, "Line #{next_position}: product must be a B2C product.")
        next
      end

      width_mm = attrs["width_mm"].to_i
      ceiling_drop_mm = attrs["ceiling_drop_mm"].to_i
      requested_quantity = [ attrs["quantity"].to_i, 1 ].max
      opening_type = attrs["opening_type"].presence || "single_open"
      finished_floor_mode = attrs["finished_floor_mode"].presence || "just_off_floor"
      track_selected = normalized_track_selected(attrs["track_selected"])

      if width_mm <= 0 || ceiling_drop_mm <= 0
        quote_request.errors.add(:base, "Line #{next_position}: width and drop must be greater than 0.")
        next
      end

      requirements = Inventory::RequirementCalculator.new(
        width_mm: width_mm,
        opening_type: opening_type,
        ceiling_drop_mm: ceiling_drop_mm,
        finished_floor_mode: finished_floor_mode,
        track_selected: track_selected
      ).calculate

      per_unit_requirements = {
        track_metres_required: requirements.track_metres_required,
        hooks_total: requirements.hooks_total,
        brackets_total: requirements.brackets_total,
        wand_quantity: attrs["wand_quantity"].to_i,
        end_cap_quantity: attrs["end_cap_quantity"].to_i,
        stopper_quantity: attrs["stopper_quantity"].to_i,
        wand_hook_quantity: attrs["wand_hook_quantity"].to_i
      }

      max_quantity = Inventory::MaxQuantityCalculator.new(
        product: product,
        requirement_per_unit: per_unit_requirements,
        requested_quantity: requested_quantity
      ).calculate

      if max_quantity.max_quantity <= 0
        quote_request.errors.add(:base, "Line #{next_position}: insufficient stock to create this order line.")
        next
      end

      if max_quantity.adjusted
        warnings << "Line #{next_position} quantity adjusted from #{requested_quantity} to #{max_quantity.adjusted_quantity} (#{max_quantity.limiting_component})."
      end

      final_quantity = max_quantity.adjusted_quantity
      pricing = Pricing::MatrixCalculator.new(
        customer_mode: quote_request.customer_mode,
        product: product,
        width_mm: width_mm,
        drop_mm: ceiling_drop_mm,
        track_selected: track_selected
      ).calculate
      if pricing.curtain_price.to_d <= 0
        quote_request.errors.add(:base, "Line #{next_position}: No matrix price is available for this product and size.")
        next
      end

      area_sqm = ((width_mm.to_d * ceiling_drop_mm.to_d) / 1_000_000).round(3)
      line_total = (pricing.line_total.to_d * final_quantity).round(2)

      quote_request.quote_items.build(
        product: product,
        line_position: next_position,
        description: attrs["description"].presence || [ attrs["location_name"].presence, product.name ].compact.join(" - "),
        quantity: final_quantity,
        area_sqm: area_sqm,
        unit_price: pricing.line_total,
        line_total: line_total,
        applied_rule_names: "Matrix pricing",
        width: (width_mm.to_d / 10).round(2),
        height: (ceiling_drop_mm.to_d / 10).round(2),
        location_name: attrs["location_name"],
        track_selected: track_selected,
        fixing: attrs["fixing"],
        opening_type: opening_type,
        opening_code: attrs["opening_code"],
        width_mm: width_mm,
        ceiling_drop_mm: ceiling_drop_mm,
        finished_floor_mode: finished_floor_mode,
        factory_drop_mm: requirements.factory_drop_mm,
        material_name: attrs["material_name"],
        material_number: attrs["material_number"],
        lv_name: attrs["lv_name"],
        high_temp_custom: attrs["high_temp_custom"],
        width_notes: attrs["width_notes"],
        wand_required: truthy?(attrs["wand_required"]) || attrs["wand_quantity"].to_i.positive?,
        wand_quantity: attrs["wand_quantity"].to_i,
        end_cap_quantity: attrs["end_cap_quantity"].to_i,
        stopper_quantity: attrs["stopper_quantity"].to_i,
        wand_hook_quantity: attrs["wand_hook_quantity"].to_i,
        curtain_price: pricing.curtain_price,
        track_price: pricing.track_price,
        hooks_display: requirements.hooks_display,
        hooks_total: requirements.hooks_total,
        brackets_total: requirements.brackets_total,
        track_metres_required: requirements.track_metres_required
      )

      next_position += 1
    end
  end

  def order_line_blank?(attrs)
    attrs["product_id"].blank? &&
      attrs["location_name"].blank? &&
      attrs["width_mm"].blank? &&
      attrs["ceiling_drop_mm"].blank?
  end

  def truthy?(value)
    %w[1 true yes y on].include?(value.to_s.strip.downcase)
  end

  def available_track_codes
    ([ "shared" ] + TrackPriceTier.distinct.order(:track_name).pluck(:track_name)).uniq
  end

  def normalized_track_selected(value)
    selected = value.to_s.strip
    return "shared" if selected.blank?
    return "none" if selected.casecmp("none").zero?

    selected
  end

  def order_workflow_status_change?(target_status)
    QuoteRequest::ORDER_WORKFLOW_STATUSES.include?(target_status) &&
      QuoteRequest::ORDER_WORKFLOW_STATUSES.include?(@quote_request.status)
  end

  def send_pickup_ready_email_if_needed(previous_status:, target_status:)
    return unless target_status == "ready_for_pick_up"
    return if previous_status == "ready_for_pick_up"
    return unless @quote_request.pickup?

    QuoteRequestMailer.ready_for_pick_up_notification(@quote_request).deliver_now
  rescue StandardError => e
    Rails.logger.error("Pickup-ready email failed for QuoteRequest ##{@quote_request.id}: #{e.class} - #{e.message}")
  end
end
