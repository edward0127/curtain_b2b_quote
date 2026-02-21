require "test_helper"

class QuoteRequestsControllerTest < ActionDispatch::IntegrationTest
  test "b2b customer can view index" do
    sign_in users(:customer)
    get quote_requests_url
    assert_response :success
  end

  test "b2b customer can create multi item quote request" do
    sign_in users(:customer)

    assert_difference("QuoteRequest.count", 1) do
      post quote_requests_url, params: {
        quote_request: {
          customer_reference: "PO-NEW-01",
          valid_until: 14.days.from_now.to_date.to_s,
          quote_template_id: quote_templates(:standard).id,
          notes: "Test quote",
          quote_items_attributes: {
            "0" => {
              line_position: 1,
              product_id: products(:sheer_panel).id,
              width: 180.0,
              height: 220.0,
              quantity: 3,
              description: "Boardroom"
            }
          }
        }
      }
    end

    created_quote = QuoteRequest.order(:id).last
    assert_equal 1, created_quote.quote_items.count
    assert_redirected_to quote_request_url(created_quote)
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
      quote_template: quote_templates(:standard),
      quote_number: "Q-20260221-90001",
      customer_reference: "PRIVATE-1",
      currency: "AUD",
      valid_until: 14.days.from_now.to_date,
      width: 111,
      height: 222,
      quantity: 1,
      notes: "Private",
      status: :submitted,
      quote_items_attributes: {
        "0" => {
          line_position: 1,
          product_id: products(:sheer_panel).id,
          width: 111,
          height: 222,
          quantity: 1,
          description: "Private line"
        }
      }
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

  test "renders quote document html for owner" do
    sign_in users(:customer)
    get document_quote_request_url(quote_requests(:one))
    assert_response :success
    assert_match quote_requests(:one).quote_number, @response.body
  end
end
