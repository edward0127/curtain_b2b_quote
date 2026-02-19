class ApplicationMailer < ActionMailer::Base
  default from: -> { AppSetting.fetch(:mail_from_email) }
  layout "mailer"

  def default_url_options
    AppSetting.mailer_default_url_options
  end
end
