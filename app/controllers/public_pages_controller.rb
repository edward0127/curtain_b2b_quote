class PublicPagesController < ApplicationController
  before_action :redirect_signed_in_user!
  before_action :build_contact_form, only: [ :home, :partners, :builders, :create_contact ]
  before_action :load_home_content, only: [ :home, :create_contact ]
  before_action :load_partners_content, only: :partners
  before_action :load_builders_content, only: :builders

  def home
    render template: "public_pages/home"
  end

  def partners
    render template: "public_pages/partners"
  end

  def builders
    render template: "public_pages/builders"
  end

  def create_contact
    @contact_form = PublicContactForm.new(contact_form_params)

    if @contact_form.valid? && deliver_contact_email(@contact_form)
      redirect_to root_path(anchor: "get-in-touch"), notice: "Thanks for reaching out. We will get back to you shortly."
    else
      render :home, status: :unprocessable_entity
    end
  end

  private

  def redirect_signed_in_user!
    return unless user_signed_in?
    return if current_user.admin?

    redirect_to dashboard_path
  end

  def build_contact_form
    @contact_form = PublicContactForm.new
  end

  def load_home_content
    @home_content = app_setting.home_page_content(preview: page_preview_requested?)
  end

  def load_partners_content
    @partners_content = app_setting.partners_page_content(preview: page_preview_requested?)
  end

  def load_builders_content
    @builders_content = app_setting.builders_page_content(preview: page_preview_requested?)
  end

  def page_preview_requested?
    current_user&.admin? && params[:preview].to_s == "1"
  end

  def contact_form_params
    params.require(:public_contact_form).permit(
      :first_name,
      :last_name,
      :email,
      :company,
      :message,
      :subscribe_updates
    )
  end

  def deliver_contact_email(contact_form)
    PublicInquiryMailer.new_public_inquiry(contact_form).deliver_now
    true
  rescue StandardError => e
    Rails.logger.error("Public inquiry email delivery failed: #{e.class} - #{e.message}")
    raise if Rails.env.development?

    contact_form.errors.add(:base, "Your message could not be sent right now. Please email info@lightvue.com.au directly.")
    false
  end
end
