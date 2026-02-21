class Admin::PricingRulesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_product
  before_action :set_pricing_rule, only: %i[ edit update destroy ]

  def new
    @pricing_rule = @product.pricing_rules.new(active: true, priority: 100, adjustment_type: :percentage)
  end

  def create
    @pricing_rule = @product.pricing_rules.new(pricing_rule_params)

    if @pricing_rule.save
      redirect_to admin_product_path(@product), notice: "Pricing rule created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @pricing_rule.update(pricing_rule_params)
      redirect_to admin_product_path(@product), notice: "Pricing rule updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @pricing_rule.destroy
    redirect_to admin_product_path(@product), notice: "Pricing rule deleted."
  end

  private

  def set_product
    @product = Product.find(params[:product_id])
  end

  def set_pricing_rule
    @pricing_rule = @product.pricing_rules.find(params[:id])
  end

  def pricing_rule_params
    params.require(:pricing_rule).permit(
      :name,
      :priority,
      :active,
      :min_area,
      :max_area,
      :min_quantity,
      :max_quantity,
      :adjustment_type,
      :adjustment_value
    )
  end
end
