require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated users" do
    get dashboard_url
    assert_redirected_to new_user_session_url
  end

  test "shows dashboard for signed-in user" do
    sign_in users(:customer)

    get dashboard_url
    assert_response :success
  end

  test "customer dashboard defaults to new quote tab" do
    sign_in users(:customer)

    get dashboard_url
    assert_response :success
    assert_select "a.tab.tab--active", text: "Submit a New Quote"
    assert_select "h3", text: "Submit Multi-Item Quote"
  end

  test "customer can open quote history tab on dashboard" do
    sign_in users(:customer)

    get dashboard_url(tab: :history)
    assert_response :success
    assert_select "a.tab.tab--active", text: "View Full Quote History"
    assert_select "h3", text: "Full Quote History"
    assert_select "a[href='#{document_quote_request_path(quote_requests(:one), format: :pdf)}']", text: "PDF"
  end

  test "admin dashboard shows recent quote requests above tab panel" do
    sign_in users(:admin)

    get dashboard_url(tab: :customers)
    assert_response :success

    body = @response.body
    assert body.index("Recent Quote Requests") < body.index("admin_dashboard_tabs")
  end

  test "admin tab switch uses turbo frame response" do
    sign_in users(:admin)

    get dashboard_url(tab: :settings), headers: { "Turbo-Frame" => "admin_dashboard_tabs" }
    assert_response :success
    assert_select "turbo-frame#admin_dashboard_tabs"
    assert_select "turbo-frame#admin_dashboard_tabs a.tab[data-turbo-frame='admin_dashboard_tabs']", count: 2
    assert_select "h3", text: "System Settings"
    assert_select "h3", text: "Recent Quote Requests", count: 0
  end

  test "admin compact tab view hides dashboard summary panels" do
    sign_in users(:admin)

    get dashboard_url(tab: :customers, compact: 1)
    assert_response :success
    assert_select "p.metric__label", text: "Latest Customers", count: 0
    assert_select "h3", text: "Recent Quote Requests", count: 0
    assert_select "turbo-frame#admin_dashboard_tabs"
  end

  test "customer tab switch uses turbo frame response" do
    sign_in users(:customer)

    get dashboard_url(tab: :history), headers: { "Turbo-Frame" => "customer_dashboard_tabs" }
    assert_response :success
    assert_select "turbo-frame#customer_dashboard_tabs"
    assert_select "turbo-frame#customer_dashboard_tabs a.tab[data-turbo-frame='customer_dashboard_tabs']", count: 2
    assert_select "h3", text: "Full Quote History"
    assert_select "p.metric__label", text: "Total Quotes", count: 0
  end
end
