require "test_helper"

class PublicPagesControllerTest < ActionDispatch::IntegrationTest
  test "guest can access homepage" do
    get root_url
    assert_response :success
    assert_select "h1", text: "Your trade partner for exceptional interiors."
  end

  test "homepage uses configurable public settings content" do
    AppSetting.current.update!(
      public_home_hero_title: "Configurable hero heading",
      public_home_hero_image: "https://example.com/configurable-home.jpg",
      public_cta_contact_label: "Reach us"
    )

    get root_url
    assert_response :success
    assert_select "h1", text: "Configurable hero heading"
    assert_select "a", text: "Reach us"
    assert_match "https://example.com/configurable-home.jpg", response.body
  end

  test "guest can access partners page" do
    get partners_url
    assert_response :success
    assert_select "h1", text: "Who we work with"
  end

  test "guest can access builders page" do
    get builders_url
    assert_response :success
    assert_select "h1", text: "The finishing touch that completes every project"
  end

  test "guest can access builders-developers route" do
    get "/builders-developers"
    assert_response :success
    assert_select "h1", text: "The finishing touch that completes every project"
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

  test "admin can open partners preview without dashboard redirect" do
    sign_in users(:admin)
    setting = AppSetting.current
    payload = setting.partners_page_content(preview: false)
    payload["texts"]["hero_title"] = "Draft Preview Heading"
    setting.save_partners_page_draft!(payload)

    get partners_url(preview: 1)
    assert_response :success
    assert_select "h1", text: "Draft Preview Heading"
    assert_select "a", text: "Return to editor"
  end

  test "admin can access frontend pages without dashboard redirect" do
    sign_in users(:admin)

    get root_url
    assert_response :success

    get partners_url
    assert_response :success

    get builders_url
    assert_response :success
  end
end
