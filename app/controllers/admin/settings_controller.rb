class Admin::SettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!

  def edit
    @app_setting = AppSetting.current
  end

  def update
    @app_setting = AppSetting.current

    if @app_setting.update(app_setting_params)
      redirect_to settings_redirect_path, notice: "Settings updated."
    else
      if return_to_dashboard?
        redirect_to dashboard_path({ tab: :settings }.merge(compact_param)), alert: @app_setting.errors.full_messages.to_sentence
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end

  private

  def return_to_dashboard?
    params[:return_to] == "dashboard"
  end

  def settings_redirect_path
    return dashboard_path({ tab: :settings }.merge(compact_param)) if return_to_dashboard?

    edit_admin_settings_path
  end

  def compact_param
    return {} unless params[:compact].to_s == "1"

    { compact: 1 }
  end

  def app_setting_params
    permitted = params.require(:app_setting).permit(
      :mailgun_domain,
      :mailgun_smtp_username,
      :mailgun_smtp_password,
      :mailgun_smtp_address,
      :mailgun_smtp_port,
      :mail_from_email,
      :quote_receiver_email,
      :bank_account_name,
      :bank_name,
      :bank_bsb,
      :bank_account_number,
      :app_host,
      :app_port,
      :app_protocol,
      :pickup_address_default,
      :delivery_note_default,
      :public_heading_font,
      :public_body_font
    )

    if permitted[:mailgun_smtp_password].blank?
      permitted.except(:mailgun_smtp_password)
    else
      permitted
    end
  end
end
