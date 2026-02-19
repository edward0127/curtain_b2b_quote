require "test_helper"

class Admin::SettingsControllerTest < ActionDispatch::IntegrationTest
  test "admin can view settings page" do
    sign_in users(:admin)

    get edit_admin_settings_url
    assert_response :success
  end

  test "admin can update settings" do
    sign_in users(:admin)
    original_password = app_settings(:default).mailgun_smtp_password

    patch admin_settings_url, params: {
      app_setting: {
        quote_receiver_email: "new.receiver@example.com",
        mail_from_email: "no-reply@new-domain.com",
        app_protocol: "https",
        mailgun_smtp_password: ""
      }
    }

    assert_redirected_to edit_admin_settings_url
    setting = AppSetting.current
    assert_equal "new.receiver@example.com", setting.quote_receiver_email
    assert_equal "no-reply@new-domain.com", setting.mail_from_email
    assert_equal "https", setting.app_protocol
    assert_equal original_password, setting.mailgun_smtp_password
  end

  test "admin update from dashboard settings tab stays on dashboard" do
    sign_in users(:admin)

    patch admin_settings_url, params: {
      return_to: "dashboard",
      app_setting: {
        quote_receiver_email: "dashboard.receiver@example.com"
      }
    }

    assert_redirected_to dashboard_url(tab: :settings)
    assert_equal "dashboard.receiver@example.com", AppSetting.current.quote_receiver_email
  end

  test "admin update from compact dashboard settings tab keeps compact mode" do
    sign_in users(:admin)

    patch admin_settings_url, params: {
      return_to: "dashboard",
      compact: "1",
      app_setting: {
        quote_receiver_email: "compact.receiver@example.com"
      }
    }

    assert_redirected_to dashboard_url(tab: :settings, compact: 1)
    assert_equal "compact.receiver@example.com", AppSetting.current.quote_receiver_email
  end

  test "b2b customer cannot access settings page" do
    sign_in users(:customer)

    get edit_admin_settings_url
    assert_redirected_to root_url
  end

  test "requires login" do
    get edit_admin_settings_url
    assert_redirected_to new_user_session_url
  end
end
