require "test_helper"

class QuoteRequestsControllerTest < ActionDispatch::IntegrationTest
  test "b2b customer can view index" do
    sign_in users(:customer)
    get quote_requests_url
    assert_response :success
    assert_select "a[href='#{quote_request_path(quote_requests(:one))}']", text: "View"
    assert_select "a[href='#{document_quote_request_path(quote_requests(:one), format: :pdf)}']", text: "PDF"
  end

  test "index shows invoice pdf label for order workflow rows" do
    quote_requests(:one).update!(status: :order_processing)
    sign_in users(:customer)

    get quote_requests_url
    assert_response :success
    assert_select "a[href='#{document_quote_request_path(quote_requests(:one), format: :pdf)}']", text: "Invoice PDF"
  end

  test "show displays invoice pdf label for order workflow when orders v2 is enabled" do
    quote_requests(:one).update!(status: :order_processing)
    sign_in users(:customer)

    get quote_request_url(quote_requests(:one))
    assert_response :success
    assert_select "a[href='#{document_quote_request_path(quote_requests(:one), format: :pdf)}']", text: "Invoice PDF"
  end

  test "create quote route redirects to b2b shop" do
    sign_in users(:customer)

    assert_no_difference("QuoteRequest.count") do
      post quote_requests_url, params: {
        quote_request: {
          customer_reference: "PO-NEW-01",
          valid_until: 14.days.from_now.to_date.to_s,
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

    assert_redirected_to b2b_shop_url
  end

  test "new quote route redirects to b2b shop" do
    sign_in users(:customer)

    get new_quote_request_url
    assert_redirected_to b2b_shop_url
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
    assert_no_match(/>Tracks</, @response.body)
    assert_no_match(/>Length</, @response.body)
    assert_no_match(/Style \(S Wave \/ Pinch Pleat\)/, @response.body)
    assert_match(/>Style</, @response.body)
    assert_match(/>Opening Code</, @response.body)
  end

  test "renders legacy track columns in quote document html when historical track details exist" do
    quote_requests(:one).quote_items.first.update!(track_selected: "M", track_price: 130, track_metres_required: 4)
    sign_in users(:customer)

    get document_quote_request_url(quote_requests(:one))
    assert_response :success
    assert_match(/>Tracks</, @response.body)
    assert_match(/>Length</, @response.body)
    assert_match(/Style \(S Wave \/ Pinch Pleat\)/, @response.body)
    assert_match(/>OW or C\/O</, @response.body)
  end

  test "renders styled pdf document for owner" do
    sign_in users(:customer)
    get document_quote_request_url(quote_requests(:one), format: :pdf)
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert @response.body.start_with?("%PDF-1.4")
  end

  test "renders invoice pdf for orders when orders v2 is enabled" do
    quote_requests(:one).update!(status: :order_processing, submitted_at: Time.current)
    sign_in users(:customer)

    get document_quote_request_url(quote_requests(:one), format: :pdf)
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert_includes @response.body, "INVOICE / ORDER"
  end
end
