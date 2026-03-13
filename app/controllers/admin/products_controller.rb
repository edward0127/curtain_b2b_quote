class Admin::ProductsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_product, only: %i[ show edit update destroy preview_price ]

  def index
    @products = Product.includes(:pricing_rules).alphabetical
    matrix_combos = PriceMatrixEntry.distinct.pluck(:channel, :product_name, :style_name)

    @pricing_labels = @products.each_with_object({}) do |product, labels|
      labels[product.id] = if product.legacy_custom_curtain?
        "Legacy pricing"
      elsif product.matrix_priced_template? &&
            matrix_combos.include?([ product.pricing_channel, product.product_type, product.style_name ])
        "Matrix pricing"
      elsif product.matrix_priced_template?
        "No matrix rows"
      else
        "Legacy pricing"
      end
    end
  end

  def show
    @pricing_rules = @product.pricing_rules.ordered
  end

  def preview_price
    @preview_input = default_preview_input
    @preview_result = nil
    @preview_error = nil
    @preview_submitted = false
    @available_matrix_channels = available_matrix_channels_for_product

    return unless preview_submitted?

    @preview_submitted = true

    @preview_input = default_preview_input.merge(preview_price_params.to_h)
    if @preview_input.blank?
      @preview_error = "Please enter customer mode, width, and drop to preview pricing."
      return
    end

    width_mm = parse_positive_integer(@preview_input["width_mm"])
    drop_mm = parse_positive_integer(@preview_input["drop_mm"])
    customer_mode = normalized_customer_mode(@preview_input["customer_mode"])
    track_requested = truthy?(@preview_input["track_selected"])

    if width_mm.nil? || drop_mm.nil?
      @preview_error = "Width and drop must be positive integers."
      return
    end

    calculator_result = Pricing::MatrixCalculator.new(
      customer_mode: customer_mode,
      product: @product,
      width_mm: width_mm,
      drop_mm: drop_mm,
      track_selected: preview_track_code(width_mm)
    ).calculate

    if calculator_result.curtain_price.to_d <= 0
      @preview_error = missing_matrix_message(
        customer_mode: customer_mode,
        width_mm: width_mm,
        drop_mm: drop_mm
      )
      return
    end

    curtain_price = calculator_result.curtain_price.to_d.round(2)
    track_price = track_requested ? calculator_result.track_price.to_d.round(2) : 0.to_d
    line_total = (curtain_price + track_price).round(2)
    gst = (line_total * BigDecimal("0.1")).round(2)

    @preview_result = {
      curtain_price: curtain_price,
      track_price: track_price,
      line_total: line_total,
      gst: gst,
      total_inc_gst: (line_total + gst).round(2)
    }
  rescue StandardError => e
    Rails.logger.error("Preview price failed for product #{@product.id}: #{e.class} - #{e.message}")
    @preview_error = "Unable to preview price right now. Please verify inputs and try again."
  end

  def new
    @product = Product.new(active: true, pricing_mode: :per_square_meter)
  end

  def create
    @product = Product.new(product_params)

    if @product.save
      redirect_to admin_product_path(@product), notice: "Product created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @product.update(product_params)
      redirect_to admin_product_path(@product), notice: "Product updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @product.destroy
    if @product.errors.any?
      redirect_to admin_products_path, alert: @product.errors.full_messages.to_sentence
    else
      redirect_to admin_products_path, notice: "Product deleted."
    end
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def product_params
    params.require(:product).permit(
      :name,
      :sku,
      :description,
      :base_price,
      :pricing_mode,
      :pricing_channel,
      :product_type,
      :style_name,
      :active,
      :track_inventory_item_id,
      :hook_inventory_item_id,
      :bracket_inventory_item_id,
      :wand_inventory_item_id,
      :end_cap_inventory_item_id,
      :stopper_inventory_item_id,
      :wand_hook_inventory_item_id
    )
  end

  def preview_price_params
    preview_params = params[:preview]
    preview_params = ActionController::Parameters.new(preview_params.to_h) if preview_params.is_a?(Hash)
    preview_params = ActionController::Parameters.new({}) if preview_params.blank?

    preview_params.permit(:customer_mode, :width_mm, :drop_mm, :track_selected)
  end

  def default_preview_input
    default_mode = Product::PRICING_CHANNELS.include?(@product.pricing_channel.to_s) ? @product.pricing_channel.to_s : "b2b"

    {
      "customer_mode" => default_mode,
      "track_selected" => "1",
      "width_mm" => "",
      "drop_mm" => ""
    }
  end

  def parse_positive_integer(value)
    input = value.to_s.strip
    input = input.delete(",").delete(" ").delete("\u00A0")
    return nil unless input.match?(/\A[1-9]\d*\z/)

    input.to_i
  end

  def normalized_customer_mode(value)
    return "b2c" if value.to_s == "b2c"

    "b2b"
  end

  def preview_track_code(width_mm)
    scoped = TrackPriceTier.where("width_band_min_mm <= ? AND width_band_max_mm >= ?", width_mm, width_mm)
    scoped.where(track_name: "shared").pick(:track_name) || scoped.order(:track_name).pick(:track_name) || "shared"
  end

  def truthy?(value)
    ActiveModel::Type::Boolean.new.cast(value)
  end

  def preview_submitted?
    params[:preview].present?
  end

  def available_matrix_channels_for_product
    product_name = @product.matrix_lookup_name
    PriceMatrixEntry.where(product_name: product_name).distinct.order(:channel).pluck(:channel)
  end

  def missing_matrix_message(customer_mode:, width_mm:, drop_mm:)
    mode = customer_mode.to_s.upcase
    base = "No matrix price found for these dimensions (#{width_mm} x #{drop_mm} mm, #{mode})."
    return base if @available_matrix_channels.include?(customer_mode.to_s)

    "#{base} This product currently has no #{mode} matrix rows imported."
  end
end
