class PublicInquiryMailer < ApplicationMailer
  def new_public_inquiry(contact_form)
    @contact_form = contact_form

    mail_options = {
      to: AppSetting.fetch(:quote_receiver_email),
      subject: "New Get In Touch Submission - #{contact_form.company}"
    }

    smtp_settings = AppSetting.smtp_settings
    mail_options[:delivery_method_options] = smtp_settings if smtp_settings.present?

    mail(mail_options)
  end
end
