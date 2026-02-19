class QuoteRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_b2b_customer!
  before_action :set_quote_request, only: [ :show ]

  def index
    @quote_requests = current_user.quote_requests.order(created_at: :desc)
  end

  def new
    @quote_request = current_user.quote_requests.new
  end

  def create
    @quote_request = current_user.quote_requests.new(quote_request_params)
    @quote_request.status = :submitted

    if @quote_request.save
      notice_message = "Quote submitted successfully."
      begin
        QuoteRequestMailer.new_quote_request(@quote_request).deliver_now
      rescue StandardError => e
        Rails.logger.error("Quote email delivery failed for QuoteRequest ##{@quote_request.id}: #{e.class} - #{e.message}")
        raise if Rails.env.development?
        notice_message = "Quote submitted, but email delivery failed. Please check SMTP settings."
      end

      redirect_to quote_request_path(@quote_request), notice: notice_message
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  private

  def set_quote_request
    @quote_request = current_user.quote_requests.find(params[:id])
  end

  def quote_request_params
    params.require(:quote_request).permit(:width, :height, :quantity, :notes)
  end
end
