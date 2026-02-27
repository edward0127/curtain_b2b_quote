require "test_helper"

class PublicPagesControllerTest < ActionDispatch::IntegrationTest
  test "guest can access homepage" do
    get root_url
    assert_response :success
    assert_select "h1", text: "Curtains & Tracks for Trade Partners"
  end

  test "guest can access partners page" do
    get partners_url
    assert_response :success
    assert_select "h1", text: "Who do we work with?"
  end

  test "guest can access builders page" do
    get builders_url
    assert_response :success
    assert_select "h1", text: "The finishing touch that lifts every project"
  end

  test "guest can access builders-developers route" do
    get "/builders-developers"
    assert_response :success
    assert_select "h1", text: "The finishing touch that lifts every project"
  end

  test "guest can submit get in touch form" do
    assert_emails 1 do
      post public_contact_url, params: {
        public_contact_form: {
          first_name: "Sam",
          last_name: "Nguyen",
          email: "sam@example.com",
          company: "Build Co",
          message: "Looking for supply support on a 24-unit project.",
          subscribe_updates: "1"
        }
      }
    end

    assert_redirected_to root_url(anchor: "get-in-touch")

    follow_redirect!
    assert_match "Thanks for reaching out", response.body
  end

  test "invalid get in touch form shows errors" do
    assert_no_emails do
      post public_contact_url, params: {
        public_contact_form: {
          first_name: "",
          last_name: "",
          email: "not-an-email",
          company: "",
          message: ""
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select ".lv-contact-errors"
  end

  test "signed in users are redirected from public pages to dashboard" do
    sign_in users(:customer)

    get root_url
    assert_redirected_to dashboard_url

    get partners_url
    assert_redirected_to dashboard_url

    get builders_url
    assert_redirected_to dashboard_url
  end
end
