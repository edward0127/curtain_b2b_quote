require "test_helper"

class Admin::QuoteRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear
    @b2c_product = products(:sheer_panel)
    @b2c_product.update!(
      product_type: "Sheer Curtain",
      style_name: "S Wave",
      pricing_channel: "b2c"
    )
    @b2b_product = products(:blackout_panel)
    @b2b_product.update!(
      pricing_channel: "b2b",
      product_type: "Blockout Curtain",
      style_name: "S Wave"
    )
    @matrixless_b2c_product = Product.create!(
      name: "Unmapped B2C Product",
      sku: "UNMAPPED-B2C-001",
      description: "No matrix rows",
      base_price: 0,
      pricing_mode: :per_unit,
      pricing_channel: "b2c",
      product_type: "Unmapped Curtain",
      style_name: "S Wave",
      active: true
    )

    PriceMatrixEntry.find_or_create_by!(
      channel: "b2b",
      product_name: "Sheer Curtain",
      style_name: "S Wave",
      width_band_min_mm: 0,
      width_band_max_mm: 6000,
      drop_band_min_mm: 0,
      drop_band_max_mm: 4000
    ) do |entry|
      entry.price = 274.4
      entry.currency = "AUD"
    end

    PriceMatrixEntry.find_or_create_by!(
      channel: "b2c",
      product_name: "Sheer Curtain",
      style_name: "S Wave",
      width_band_min_mm: 0,
      width_band_max_mm: 6000,
      drop_band_min_mm: 0,
      drop_band_max_mm: 4000
    ) do |entry|
      entry.price = 274.4
      entry.currency = "AUD"
    end

    TrackPriceTier.find_or_create_by!(
      track_name: "M",
      width_band_min_mm: 0,
      width_band_max_mm: 6000
    ) do |tier|
      tier.price = 130
      tier.currency = "AUD"
    end
  end

  test "new admin order page is b2c only" do
    sign_in users(:admin)

    get new_admin_quote_request_url
    assert_response :success
    assert_includes @response.body, "Create B2C Order"
    assert_not_includes @response.body, "B2B customer account"
    assert_includes @response.body, @b2c_product.name
    assert_not_includes @response.body, @b2b_product.name
    assert_not_includes @response.body, @matrixless_b2c_product.name
    assert_select "input[type='hidden'][name='quote_request[customer_mode]'][value='b2c']"
    assert_select "table.admin-order-lines-table tbody tr", minimum: 6
    assert_select "select[name*='[finished_floor_mode]']"
    assert_select "button[data-action='admin-order-lines#addLine']", text: "Add another line"
  end

  test "new admin order page allows larger line counts" do
    sign_in users(:admin)

    get new_admin_quote_request_url(line_count: 9)
    assert_response :success
    assert_select "table.admin-order-lines-table tbody tr", count: 9
  end

  test "admin index only shows order workflow status tabs" do
    sign_in users(:admin)

    get admin_quote_requests_url
    assert_response :success
    assert_select "a.tab", text: "All"
    assert_select "a.tab", text: "Order Processing"
    assert_select "a.tab", text: "Ready For Pick Up"
    assert_select "a.tab", text: "Completed"
    assert_select "a.tab", text: "Cancelled"
    assert_select "a.tab", text: "Submitted", count: 0
    assert_select "a.tab", text: "Reviewed", count: 0
    assert_select "a.tab", text: "Priced", count: 0
    assert_select "a.tab", text: "Sent To Customer", count: 0
    assert_select "a.tab", text: "Approved", count: 0
    assert_select "a.tab", text: "Rejected", count: 0
    assert_select "a.tab", text: "Converted To Job", count: 0
  end

  test "admin index all view excludes legacy statuses" do
    sign_in users(:admin)
    order_quote = quote_requests(:one)
    order_quote.update!(status: :order_processing, submitted_at: Time.current)
    legacy_quote = quote_requests(:two)
    legacy_quote.update!(status: :reviewed, submitted_at: nil)

    get admin_quote_requests_url
    assert_response :success
    assert_includes @response.body, order_quote.quote_number
    assert_not_includes @response.body, legacy_quote.quote_number
  end

  test "admin can create and submit b2c order with stock deduction and emails" do
    sign_in users(:admin)
    track = InventoryItem.create!(name: "Track", component_type: :track, on_hand: 20)
    hook = InventoryItem.create!(name: "Hook", component_type: :hook, on_hand: 500)
    bracket = InventoryItem.create!(name: "Bracket", component_type: :bracket, on_hand: 200)
    @b2c_product.update!(track_inventory_item: track, hook_inventory_item: hook, bracket_inventory_item: bracket)

    assert_difference("QuoteRequest.count", 1) do
      assert_difference("ActionMailer::Base.deliveries.size", 2) do
        post admin_quote_requests_url, params: {
          quote_request: {
            customer_mode: "b2c",
            customer_name: "Walk-in Customer",
            company_name: "Walk-in Co",
            customer_email: "walkin@example.com",
            customer_phone: "0400000000",
            pickup_method: "delivery",
            customer_reference: "ORD-1001",
            valid_until: 14.days.from_now.to_date.to_s,
            notes: "Admin order submission test",
            quote_items_attributes: {
              "0" => {
                line_position: 1,
                location_name: "Living Room",
                product_id: @b2c_product.id,
                width_mm: 3830,
                ceiling_drop_mm: 2410,
                opening_type: "single_open",
                finished_floor_mode: "puddled",
                track_selected: "M",
                fixing: "TF",
                quantity: 2
              }
            }
          }
        }
      end
    end

    created = QuoteRequest.order(:id).last
    assert_redirected_to admin_quote_request_url(created)
    assert_equal "order_processing", created.status
    assert_not_nil created.submitted_at
    assert_equal users(:admin).id, created.created_by_user_id
    assert_equal "walkin@example.com", created.customer_email
    assert_equal "b2c", created.customer_mode

    item = created.quote_items.first
    assert_equal 2, item.quantity
    assert_equal "puddled", item.finished_floor_mode
    assert_equal 2410, item.factory_drop_mm
    assert_equal BigDecimal("274.4"), item.curtain_price.to_d
    assert_equal BigDecimal("130.0"), item.track_price.to_d
    assert_equal BigDecimal("808.8"), item.line_total.to_d

    assert_equal 12, track.reload.on_hand
    assert_equal 356, hook.reload.on_hand
    assert_equal 186, bracket.reload.on_hand

    recipients = ActionMailer::Base.deliveries.flat_map(&:to)
    assert_includes recipients, "walkin@example.com"
    assert_includes recipients, AppSetting.current.quote_receiver_email
  end

  test "insufficient stock auto adjusts quantity with warning" do
    sign_in users(:admin)
    track = InventoryItem.create!(name: "Track", component_type: :track, on_hand: 20)
    hook = InventoryItem.create!(name: "Hook", component_type: :hook, on_hand: 100)
    bracket = InventoryItem.create!(name: "Bracket", component_type: :bracket, on_hand: 200)
    @b2c_product.update!(track_inventory_item: track, hook_inventory_item: hook, bracket_inventory_item: bracket)

    post admin_quote_requests_url, params: {
      quote_request: {
        customer_mode: "b2c",
        customer_name: "Auto Adjust Customer",
        company_name: "Auto Adjust Co",
        customer_email: "autoadjust@example.com",
        pickup_method: "delivery",
        quote_items_attributes: {
          "0" => {
            line_position: 1,
            location_name: "Bedroom",
            product_id: @b2c_product.id,
            width_mm: 3830,
            ceiling_drop_mm: 2410,
            opening_type: "single_open",
            track_selected: "M",
            fixing: "TF",
            quantity: 2
          }
        }
      }
    }

    created = QuoteRequest.order(:id).last
    assert_redirected_to admin_quote_request_url(created)
    assert_match(/adjusted/i, flash[:notice])
    assert_equal 1, created.quote_items.first.quantity
    assert_equal 28, hook.reload.on_hand
  end

  test "admin builder rejects b2b mode submissions" do
    sign_in users(:admin)

    assert_no_difference("QuoteRequest.count") do
      post admin_quote_requests_url, params: {
        quote_request: {
          customer_mode: "b2b",
          customer_user_id: users(:customer).id,
          customer_name: "B2B Attempt",
          company_name: "Should Fail Pty Ltd",
          customer_email: "b2b-attempt@example.com",
          pickup_method: "delivery",
          quote_items_attributes: {
            "0" => {
              line_position: 1,
              location_name: "Bedroom",
              product_id: @b2c_product.id,
              width_mm: 3830,
              ceiling_drop_mm: 2410,
              opening_type: "single_open",
              track_selected: "M",
              fixing: "TF",
              quantity: 1
            }
          }
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes @response.body, "Admin order builder only supports B2C orders."
  end

  test "b2c order requires company name" do
    sign_in users(:admin)

    assert_no_difference("QuoteRequest.count") do
      post admin_quote_requests_url, params: {
        quote_request: {
          customer_mode: "b2c",
          customer_name: "Walk-in Customer",
          customer_email: "walkin@example.com",
          pickup_method: "pickup",
          quote_items_attributes: {
            "0" => {
              line_position: 1,
              location_name: "Office",
              product_id: @b2c_product.id,
              width_mm: 3000,
              ceiling_drop_mm: 2400,
              opening_type: "single_open",
              track_selected: "M",
              fixing: "TF",
              quantity: 1
            }
          }
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes @response.body, "Company name can&#39;t be blank"
  end

  test "admin can open invoice and factory outputs" do
    sign_in users(:admin)
    quote = quote_requests(:one)

    get invoice_admin_quote_request_url(quote, format: :pdf)
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert @response.body.start_with?("%PDF-1.4")

    get to_chinese_factory_admin_quote_request_url(quote)
    assert_response :success
    assert_includes @response.body, "Fabric details (TO GZ FACTORY)"

    get to_chinese_factory_admin_quote_request_url(quote, format: :pdf)
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert @response.body.start_with?("%PDF-1.4")
  end

  test "admin builder rejects non-b2c product lines" do
    sign_in users(:admin)

    assert_no_difference("QuoteRequest.count") do
      post admin_quote_requests_url, params: {
        quote_request: {
          customer_mode: "b2c",
          customer_name: "Walk-in Customer",
          company_name: "Walk-in Co",
          customer_email: "walkin@example.com",
          pickup_method: "delivery",
          quote_items_attributes: {
            "0" => {
              line_position: 1,
              location_name: "Living Room",
              product_id: @b2b_product.id,
              width_mm: 3830,
              ceiling_drop_mm: 2410,
              opening_type: "single_open",
              track_selected: "M",
              fixing: "TF",
              quantity: 1
            }
          }
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes @response.body, "Line 1: product must be a B2C product."
  end

  test "admin builder rejects b2c products with no matrix price" do
    sign_in users(:admin)
    matrixless_product = products(:blackout_panel)
    matrixless_product.update!(
      pricing_channel: "b2c",
      product_type: "Unmapped Curtain",
      style_name: "S Wave",
      active: true
    )

    assert_no_difference("QuoteRequest.count") do
      post admin_quote_requests_url, params: {
        quote_request: {
          customer_mode: "b2c",
          customer_name: "Walk-in Customer",
          company_name: "Walk-in Co",
          customer_email: "walkin@example.com",
          pickup_method: "delivery",
          quote_items_attributes: {
            "0" => {
              line_position: 1,
              location_name: "Living Room",
              product_id: matrixless_product.id,
              width_mm: 3830,
              ceiling_drop_mm: 2410,
              opening_type: "single_open",
              track_selected: "M",
              fixing: "TF",
              quantity: 1
            }
          }
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes @response.body, "No matrix price is available for this product and size."
  end

  test "admin show uses order heading in metadata table for order workflow quote" do
    sign_in users(:admin)
    quote = quote_requests(:one)
    quote.update!(status: :order_processing)

    get admin_quote_request_url(quote)
    assert_response :success
    assert_select "table.order-lines-sheet__meta th", text: "Order"
  end

  test "admin show keeps quote heading in metadata table outside order workflow" do
    sign_in users(:admin)
    quote = quote_requests(:one)
    quote.update!(status: :submitted)

    get admin_quote_request_url(quote)
    assert_response :success
    assert_select "table.order-lines-sheet__meta th", text: "Quote"
  end

  test "status update to ready for pick up sends pickup email only for pickup orders" do
    sign_in users(:admin)
    pickup_order = quote_requests(:one)
    pickup_order.update!(
      status: :order_processing,
      customer_mode: :b2b,
      pickup_method: :pickup,
      customer_email: "pickup@example.com"
    )

    assert_difference("ActionMailer::Base.deliveries.size", 1) do
      patch update_status_admin_quote_request_url(pickup_order), params: { status: "ready_for_pick_up" }
    end

    pickup_order.reload
    assert_equal "ready_for_pick_up", pickup_order.status
    assert_not_nil pickup_order.ready_for_pick_up_at
    assert_equal [ "pickup@example.com" ], ActionMailer::Base.deliveries.last.to

    delivery_order = quote_requests(:two)
    delivery_order.update!(
      status: :order_processing,
      customer_mode: :b2b,
      pickup_method: :delivery,
      customer_email: "delivery@example.com"
    )

    assert_no_difference("ActionMailer::Base.deliveries.size") do
      patch update_status_admin_quote_request_url(delivery_order), params: { status: "ready_for_pick_up" }
    end
  end
end
