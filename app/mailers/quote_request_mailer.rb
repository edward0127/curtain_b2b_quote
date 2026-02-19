class QuoteRequestMailer < ApplicationMailer
  def new_quote_request(quote_request)
    @quote_request = quote_request
    @customer = quote_request.user
    recipient = AppSetting.fetch(:quote_receiver_email)
    mail_options = {
      to: recipient,
      subject: "New Curtain Quote Request ##{quote_request.id}"
    }
    smtp_settings = AppSetting.smtp_settings
    mail_options[:delivery_method_options] = smtp_settings if smtp_settings.present?

    mail(mail_options)
  end
end
