class B2b::ShopController < B2b::BaseController
  before_action :set_product, only: :show

  def index
    @products = Product.orderable_for_channel("b2b")
  end

  def show
  end

  private

  def set_product
    @product = Product.orderable_for_channel("b2b").find(params[:id])
  end
end
