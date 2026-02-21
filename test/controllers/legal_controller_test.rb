require "test_helper"

class LegalControllerTest < ActionDispatch::IntegrationTest
  test "terms page is publicly accessible" do
    get terms_url
    assert_response :success
    assert_select "h2", text: "Terms of Service"
  end

  test "privacy page is publicly accessible" do
    get privacy_url
    assert_response :success
    assert_select "h2", text: "Privacy Policy"
  end
end
