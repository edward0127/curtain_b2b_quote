class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    if current_user.admin?
      @admin_tab = params[:tab].to_s.in?(%w[ customers settings ]) ? params[:tab].to_s : "customers"
      @admin_compact = params[:compact].to_s == "1"
      @customers = User.b2b_customer.order(created_at: :desc)
      @recent_quotes = QuoteRequest.includes(:user, :quote_items).recent_first.limit(10)
      @active_products_count = Product.active.count
      @active_jobs_count = Job.open.count
      @app_setting = AppSetting.current if @admin_tab == "settings"

      if turbo_frame_request_for?("admin_dashboard_tabs")
        render partial: "dashboard/admin_tabs"
      end
    else
      @customer_tab = params[:tab].to_s.in?(%w[ new_quote history ]) ? params[:tab].to_s : "new_quote"
      @quote_history = current_user.quote_requests.includes(:quote_items).recent_first
      @recent_quotes = @quote_history.limit(10)

      if turbo_frame_request_for?("customer_dashboard_tabs")
        render partial: "dashboard/customer_tabs"
      end
    end
  end

  private

  def turbo_frame_request_for?(frame_id)
    turbo_frame_request? && request.headers["Turbo-Frame"] == frame_id
  end
end
