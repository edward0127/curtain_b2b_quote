class QuoteRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_b2b_customer!
  before_action :redirect_to_shop_for_new_orders!, only: %i[ new create ]
  before_action :set_quote_request, only: %i[ show document ]

  def index
    @quote_requests = current_user.quote_requests.includes(quote_items: :product).recent_first
  end

  def new
    redirect_to b2b_shop_path, notice: "Use the shop to build new orders."
  end

  def create
    redirect_to b2b_shop_path, notice: "Use the shop to build new orders."
  end

  def show
  end

  def document
    respond_to do |format|
      format.html
      format.pdf do
        invoice_pdf = use_invoice_pdf_renderer?(@quote_request)
        renderer = invoice_pdf ? InvoicePdfRenderer : QuotePdfRenderer
        pdf_bytes = renderer.new(@quote_request).render
        send_data(
          pdf_bytes,
          filename: invoice_pdf ? "Invoice-#{@quote_request.quote_number}.pdf" : "#{@quote_request.quote_number}.pdf",
          type: "application/pdf",
          disposition: "attachment"
        )
      end
    end
  end

  private

  def set_quote_request
    @quote_request = current_user.quote_requests.includes(quote_items: :product).find(params[:id])
  end

  def redirect_to_shop_for_new_orders!
    redirect_to b2b_shop_path, notice: "Use the shop to build new orders."
  end

  def use_invoice_pdf_renderer?(quote_request)
    QuoteRequest::ORDER_WORKFLOW_STATUSES.include?(quote_request.status)
  end
end
