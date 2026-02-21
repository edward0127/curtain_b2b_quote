class ImpersonationsController < ApplicationController
  before_action :authenticate_user!

  def destroy
    admin_user = User.admin.find_by(id: session[:impersonator_admin_user_id])
    session.delete(:impersonator_admin_user_id)

    if admin_user.present?
      sign_in(:user, admin_user)
      redirect_to dashboard_path(tab: :customers, compact: 1), notice: "Returned to admin account."
    else
      redirect_to dashboard_path, alert: "No active impersonation session."
    end
  end
end
