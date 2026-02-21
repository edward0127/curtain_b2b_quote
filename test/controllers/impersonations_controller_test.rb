require "test_helper"

class ImpersonationsControllerTest < ActionDispatch::IntegrationTest
  test "requires login" do
    delete impersonation_url
    assert_redirected_to new_user_session_url
  end

  test "returns alert if no active impersonation session exists" do
    sign_in users(:customer)

    delete impersonation_url
    assert_redirected_to dashboard_url

    follow_redirect!
    assert_match "No active impersonation session.", response.body
  end
end
