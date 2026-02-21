class Admin::ProductsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_product, only: %i[ show edit update destroy ]

  def index
    @products = Product.includes(:pricing_rules).alphabetical
  end

  def show
    @pricing_rules = @product.pricing_rules.ordered
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
    params.require(:product).permit(:name, :sku, :description, :base_price, :pricing_mode, :active)
  end
end
