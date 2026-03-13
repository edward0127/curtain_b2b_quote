class QuoteRequestMailer < ApplicationMailer
  def customer_order_invoice(quote_request)
    @quote_request = quote_request
    @quotation = Orders::QuotationPresenter.new(quote_request)
    recipient = quote_request.customer_email.presence || quote_request.user.email

    mail_options = {
      to: recipient,
      subject: "Invoice / Order #{quote_request.quote_number}"
    }
    smtp_settings = AppSetting.smtp_settings
    mail_options[:delivery_method_options] = smtp_settings if smtp_settings.present?

    mail(mail_options)
  end

  def internal_order_notification(quote_request)
    @quote_request = quote_request
    @customer_contact = quote_request.customer_email.presence || quote_request.user.email
    recipient = AppSetting.fetch(:quote_receiver_email)

    mail_options = {
      to: recipient,
      subject: "New Order Submitted #{quote_request.quote_number}"
    }
    smtp_settings = AppSetting.smtp_settings
    mail_options[:delivery_method_options] = smtp_settings if smtp_settings.present?

    mail(mail_options)
  end

  def ready_for_pick_up_notification(quote_request)
    @quote_request = quote_request
    @pickup_address = AppSetting.fetch(:pickup_address_default)
    @delivery_note = AppSetting.fetch(:delivery_note_default)
    recipient = quote_request.customer_email.presence || quote_request.user.email

    mail_options = {
      to: recipient,
      subject: "Order Ready for Pick Up #{quote_request.quote_number}"
    }
    smtp_settings = AppSetting.smtp_settings
    mail_options[:delivery_method_options] = smtp_settings if smtp_settings.present?

    mail(mail_options)
  end
end
