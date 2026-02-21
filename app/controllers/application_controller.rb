class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :impersonating?, :impersonator_admin_user

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
end
