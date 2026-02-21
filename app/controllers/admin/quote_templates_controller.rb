class Admin::QuoteTemplatesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_quote_template, only: %i[ edit update destroy ]

  def index
    @quote_templates = QuoteTemplate.alphabetical
  end

  def new
    @quote_template = QuoteTemplate.new
  end

  def create
    @quote_template = QuoteTemplate.new(quote_template_params)

    if @quote_template.save
      redirect_to admin_quote_templates_path, notice: "Quote template created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @quote_template.update(quote_template_params)
      redirect_to admin_quote_templates_path, notice: "Quote template updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @quote_template.destroy
    if @quote_template.errors.any?
      redirect_to admin_quote_templates_path, alert: @quote_template.errors.full_messages.to_sentence
    else
      redirect_to admin_quote_templates_path, notice: "Quote template deleted."
    end
  end

  private

  def set_quote_template
    @quote_template = QuoteTemplate.find(params[:id])
  end

  def quote_template_params
    params.require(:quote_template).permit(:name, :heading, :intro, :terms, :footer, :default_template)
  end
end
