class PublicPagesController < ApplicationController
  before_action :redirect_signed_in_user!
  before_action :build_contact_form, only: [ :home, :partners, :builders ]

  def home
  end

  def partners
  end

  def builders
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
    redirect_to dashboard_path if user_signed_in?
  end

  def build_contact_form
    @contact_form = PublicContactForm.new
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
