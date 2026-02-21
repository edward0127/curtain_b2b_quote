class Admin::QuoteRequestsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_quote_request, only: %i[ show update update_status convert_to_job document ]
  before_action :load_templates, only: %i[ show update ]

  def index
    @status_filter = params[:status].presence
    @quote_requests = QuoteRequest.includes(:user, :job, quote_items: :product).recent_first
    @quote_requests = @quote_requests.where(status: @status_filter) if @status_filter.present?
  end

  def show
  end

  def update
    if @quote_request.update(admin_quote_request_params)
      redirect_to admin_quote_request_path(@quote_request), notice: "Quote details updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def update_status
    @quote_request.transition_to!(params[:status])
    redirect_to admin_quote_request_path(@quote_request), notice: "Quote status updated to #{@quote_request.status.humanize}."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to admin_quote_request_path(@quote_request), alert: e.message
  end

  def convert_to_job
    created_job = @quote_request.convert_to_job!(notes: params[:job_notes])
    redirect_to admin_job_path(created_job), notice: "Quote converted to job #{created_job.job_number}."
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to admin_quote_request_path(@quote_request), alert: e.message
  end

  def document
    respond_to do |format|
      format.html { render template: "quote_requests/document" }
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
    @quote_request = QuoteRequest.includes(:quote_template, :job, :user, quote_items: :product).find(params[:id])
  end

  def load_templates
    @quote_templates = QuoteTemplate.alphabetical
  end

  def admin_quote_request_params
    params.require(:quote_request).permit(:customer_reference, :valid_until, :quote_template_id, :notes)
  end
end
