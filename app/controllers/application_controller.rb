class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :impersonating?, :impersonator_admin_user
  helper_method :app_setting, :render_public_shell?, :public_edit_mode?

  protected

  def require_admin!
    return if current_user&.admin?

    redirect_to root_path, alert: "You are not authorized to access this page."
  end

  def require_b2b_customer!
    return if current_user&.b2b_customer?

    redirect_to root_path, alert: "Only B2B customer accounts can submit quotes."
  end

  def after_sign_in_path_for(_resource)
    dashboard_path
  end

  def impersonating?
    session[:impersonator_admin_user_id].present?
  end

  def impersonator_admin_user
    return nil unless impersonating?

    @impersonator_admin_user ||= User.admin.find_by(id: session[:impersonator_admin_user_id])
  end

  def app_setting
    @app_setting ||= AppSetting.current
  end

  def render_public_shell?
    return true unless user_signed_in?
    return false unless current_user&.admin?

    controller_name == "partners_editor" || controller_name == "public_pages"
  end

  def public_edit_mode?
    return false unless current_user&.admin?

    controller_name == "partners_editor" || (controller_name == "public_pages" && [ params[:edit].to_s, params[:preview].to_s ].include?("1"))
  end
end
