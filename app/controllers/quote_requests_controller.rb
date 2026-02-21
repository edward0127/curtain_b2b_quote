class QuoteRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_b2b_customer!
  before_action :set_quote_request, only: %i[ show document ]
  before_action :load_quote_builder_collections, only: %i[ new create ]

  def index
    @quote_requests = current_user.quote_requests.includes(:quote_template, quote_items: :product).recent_first
  end

  def new
    @quote_request = current_user.quote_requests.new(valid_until: 14.days.from_now.to_date)
    build_quote_items(@quote_request)
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
      build_quote_items(@quote_request)
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def document
    respond_to do |format|
      format.html
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

  private

  def set_quote_request
    @quote_request = current_user.quote_requests.includes(:quote_template, quote_items: :product).find(params[:id])
  end

  def load_quote_builder_collections
    @products = Product.active.alphabetical
    @quote_templates = QuoteTemplate.alphabetical
  end

  def build_quote_items(quote_request)
    existing_count = quote_request.quote_items.reject(&:marked_for_destruction?).size
    target_count = [ existing_count, 3 ].max

    (target_count - existing_count).times do |offset|
      quote_request.quote_items.build(line_position: existing_count + offset + 1, quantity: 1)
    end
  end

  def quote_request_params
    params.require(:quote_request).permit(
      :customer_reference,
      :valid_until,
      :quote_template_id,
      :notes,
      quote_items_attributes: [
        :id,
        :line_position,
        :product_id,
        :description,
        :width,
        :height,
        :quantity,
        :_destroy
      ]
    )
  end
end
