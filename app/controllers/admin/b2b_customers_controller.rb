class Admin::B2bCustomersController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_b2b_customer, only: [ :edit, :update, :destroy, :impersonate ]

  def index
    @b2b_customers = User.b2b_customer.order(created_at: :desc)
  end

  def new
    @b2b_customer = User.new(role: :b2b_customer)
  end

  def create
    @b2b_customer = User.new(b2b_customer_params.merge(role: :b2b_customer))

    if @b2b_customer.save
      redirect_to admin_b2b_customers_path, notice: "B2B customer created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @b2b_customer.assign_attributes(b2b_customer_params_for_update)
    @b2b_customer.role = :b2b_customer

    if @b2b_customer.save
      redirect_to admin_b2b_customers_path, notice: "B2B customer updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @b2b_customer.destroy
    redirect_to admin_b2b_customers_path, notice: "B2B customer deleted."
  end

  def impersonate
    session[:impersonator_admin_user_id] = current_user.id
    sign_in(:user, @b2b_customer)
    redirect_to dashboard_path(tab: :new_quote), notice: "Now logged in as #{@b2b_customer.email}."
  end

  private

  def set_b2b_customer
    @b2b_customer = User.b2b_customer.find(params[:id])
  end

  def b2b_customer_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end

  def b2b_customer_params_for_update
    permitted = b2b_customer_params
    if permitted[:password].blank? && permitted[:password_confirmation].blank?
      permitted.except(:password, :password_confirmation)
    else
      permitted
    end
  end
end
