class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    if current_user.admin?
      @admin_tab = params[:tab].to_s.in?(%w[ customers settings ]) ? params[:tab].to_s : "customers"
      @admin_compact = params[:compact].to_s == "1"
      @customers = User.b2b_customer.order(created_at: :desc)
      @recent_quotes = QuoteRequest.includes(:user).order(created_at: :desc).limit(10)
      @app_setting = AppSetting.current if @admin_tab == "settings"

      if turbo_frame_request?
        render partial: "dashboard/admin_tabs"
      end
    else
      @customer_tab = params[:tab].to_s.in?(%w[ new_quote history ]) ? params[:tab].to_s : "new_quote"
      @quote_history = current_user.quote_requests.order(created_at: :desc)
      @recent_quotes = @quote_history.limit(10)
      @quote_request = current_user.quote_requests.new if @customer_tab == "new_quote"

      if turbo_frame_request?
        render partial: "dashboard/customer_tabs"
      end
    end
  end
end
