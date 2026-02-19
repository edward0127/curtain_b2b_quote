require "test_helper"

class QuoteRequestsControllerTest < ActionDispatch::IntegrationTest
  test "b2b customer can view index" do
    sign_in users(:customer)
    get quote_requests_url
    assert_response :success
  end

  test "b2b customer can create quote request" do
    sign_in users(:customer)

    assert_difference("QuoteRequest.count", 1) do
      post quote_requests_url, params: {
        quote_request: {
          width: 180.0,
          height: 220.0,
          quantity: 3,
          notes: "Test quote"
        }
      }
    end

    assert_redirected_to quote_request_url(QuoteRequest.order(:id).last)
  end

  test "admin cannot access quote form" do
    sign_in users(:admin)
    get new_quote_request_url
    assert_redirected_to root_url
  end

  test "users cannot access another customer's quote request" do
    another_customer = User.create!(
      email: "another@example.com",
      password: "Password123!",
      password_confirmation: "Password123!",
      role: :b2b_customer
    )
    foreign_quote = another_customer.quote_requests.create!(
      width: 111,
      height: 222,
      quantity: 1,
      notes: "Private",
      status: :submitted
    )

    sign_in users(:customer)
    get quote_request_url(foreign_quote)
    assert_response :not_found
  end

  test "requires login" do
    get quote_requests_url
    assert_redirected_to new_user_session_url
  end

  test "shows quote request for owner" do
    sign_in users(:customer)
    get quote_request_url(quote_requests(:one))
    assert_response :success
  end
end
