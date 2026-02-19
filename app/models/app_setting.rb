class AppSetting < ApplicationRecord
  ENV_KEYS = {
    mailgun_domain: "MAILGUN_DOMAIN",
    mailgun_smtp_username: "MAILGUN_SMTP_USERNAME",
    mailgun_smtp_password: "MAILGUN_SMTP_PASSWORD",
    mailgun_smtp_address: "MAILGUN_SMTP_ADDRESS",
    mailgun_smtp_port: "MAILGUN_SMTP_PORT",
    mail_from_email: "MAIL_FROM_EMAIL",
    quote_receiver_email: "QUOTE_RECEIVER_EMAIL",
    app_host: "APP_HOST",
    app_port: "APP_PORT",
    app_protocol: "APP_PROTOCOL"
  }.freeze

  DEFAULTS = {
    mailgun_domain: "email.tudouke.com",
    mailgun_smtp_username: "postmaster@email.tudouke.com",
    mailgun_smtp_password: "",
    mailgun_smtp_address: "smtp.mailgun.org",
    mailgun_smtp_port: 587,
    mail_from_email: "no-reply@email.tudouke.com",
    quote_receiver_email: "edward0127@hotmail.com",
    app_host: "localhost",
    app_port: 3000,
    app_protocol: "http"
  }.freeze

  validates :mailgun_smtp_port, numericality: { only_integer: true, greater_than: 0 }
  validates :app_port, numericality: { only_integer: true, greater_than: 0 }
  validates :mail_from_email, :quote_receiver_email, :mailgun_smtp_address, :mailgun_domain, :app_host, :app_protocol, presence: true
  validates :mailgun_smtp_username, presence: true

  before_validation :apply_defaults

  def self.current
    first || create_with(default_attributes).create!
  end

  def self.fetch(key)
    setting = current
    value = setting.public_send(key)
    return value unless value.blank?

    fallback_for(key)
  end

  def self.smtp_settings
    return nil unless smtp_configured?

    {
      address: fetch(:mailgun_smtp_address),
      port: fetch(:mailgun_smtp_port).to_i,
      domain: fetch(:mailgun_domain),
      user_name: fetch(:mailgun_smtp_username),
      password: fetch(:mailgun_smtp_password),
      authentication: :plain,
      enable_starttls_auto: true
    }
  end

  def self.smtp_configured?
    fetch(:mailgun_smtp_username).present? && fetch(:mailgun_smtp_password).present?
  end

  def self.mailer_default_url_options
    {
      host: fetch(:app_host),
      port: fetch(:app_port).to_i,
      protocol: fetch(:app_protocol)
    }
  end

  def self.default_attributes
    {
      "mailgun_domain" => env_or_default(:mailgun_domain),
      "mailgun_smtp_username" => env_or_default(:mailgun_smtp_username),
      "mailgun_smtp_password" => env_or_default(:mailgun_smtp_password),
      "mailgun_smtp_address" => env_or_default(:mailgun_smtp_address),
      "mailgun_smtp_port" => env_or_default(:mailgun_smtp_port).to_i,
      "mail_from_email" => env_or_default(:mail_from_email),
      "quote_receiver_email" => env_or_default(:quote_receiver_email),
      "app_host" => env_or_default(:app_host),
      "app_port" => env_or_default(:app_port).to_i,
      "app_protocol" => env_or_default(:app_protocol)
    }
  end

  def apply_defaults
    attrs = self.class.default_attributes

    self.mailgun_domain = attrs["mailgun_domain"] if mailgun_domain.blank?
    self.mailgun_smtp_username = attrs["mailgun_smtp_username"] if mailgun_smtp_username.blank?
    self.mailgun_smtp_password = attrs["mailgun_smtp_password"] if mailgun_smtp_password.blank?
    self.mailgun_smtp_address = attrs["mailgun_smtp_address"] if mailgun_smtp_address.blank?
    self.mailgun_smtp_port = attrs["mailgun_smtp_port"] if mailgun_smtp_port.blank?
    self.mail_from_email = attrs["mail_from_email"] if mail_from_email.blank?
    self.quote_receiver_email = attrs["quote_receiver_email"] if quote_receiver_email.blank?
    self.app_host = attrs["app_host"] if app_host.blank?
    self.app_port = attrs["app_port"] if app_port.blank?
    self.app_protocol = attrs["app_protocol"] if app_protocol.blank?
  end

  def self.fallback_for(key)
    env_or_default(key)
  end

  def self.env_or_default(key)
    ENV.fetch(ENV_KEYS.fetch(key), DEFAULTS.fetch(key))
  end

  private_class_method :fallback_for, :env_or_default
end
