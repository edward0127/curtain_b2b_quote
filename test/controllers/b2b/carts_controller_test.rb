require "test_helper"

class B2b::CartsControllerTest < ActionDispatch::IntegrationTest
  setup do
    ActionMailer::Base.deliveries.clear

    @product = products(:sheer_panel)
    @product.update!(
      product_type: "Sheer Curtain",
      style_name: "S Wave",
      pricing_channel: "b2b"
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

    TrackPriceTier.find_or_create_by!(
      track_name: "M",
      width_band_min_mm: 0,
      width_band_max_mm: 6000
    ) do |tier|
      tier.price = 130
      tier.currency = "AUD"
    end
  end

  test "b2b customer can add cart line and checkout order" do
    sign_in users(:customer)
    track = InventoryItem.create!(name: "Track", component_type: :track, on_hand: 20)
    hook = InventoryItem.create!(name: "Hook", component_type: :hook, on_hand: 500)
    bracket = InventoryItem.create!(name: "Bracket", component_type: :bracket, on_hand: 200)
    @product.update!(track_inventory_item: track, hook_inventory_item: hook, bracket_inventory_item: bracket)

    assert_difference("QuoteRequest.count", 1) do
      post add_line_b2b_cart_url, params: {
        line: {
          product_id: @product.id,
          location_name: "Living Room",
          width_mm: 3830,
          ceiling_drop_mm: 2410,
          opening_type: "single_open",
          finished_floor_mode: "just_off_floor",
          track_selected: "M",
          fixing: "TF",
          quantity: 2
        }
      }
    end
    assert_redirected_to b2b_cart_url
    draft_cart = QuoteRequest.order(:id).last
    assert_nil draft_cart.submitted_at
    assert_equal "order_processing", draft_cart.status
    assert_equal 1, draft_cart.quote_items.count

    assert_no_difference("QuoteRequest.count") do
      assert_difference("ActionMailer::Base.deliveries.size", 2) do
        post checkout_b2b_cart_url, params: {
          checkout: {
            pickup_method: "delivery",
            customer_reference: "B2B-PO-900"
          }
        }
      end
    end

    created = draft_cart.reload
    assert_redirected_to quote_request_url(created)
    assert_equal "order_processing", created.status
    assert_equal users(:customer).email, created.customer_email
    assert_not_nil created.submitted_at
    assert_equal 2, created.quote_items.first.quantity

    assert_equal 12, track.reload.on_hand
    assert_equal 356, hook.reload.on_hand
    assert_equal 186, bracket.reload.on_hand
  end

  test "checkout auto adjusts quantity when stock is insufficient" do
    sign_in users(:customer)
    track = InventoryItem.create!(name: "Track", component_type: :track, on_hand: 20)
    hook = InventoryItem.create!(name: "Hook", component_type: :hook, on_hand: 100)
    bracket = InventoryItem.create!(name: "Bracket", component_type: :bracket, on_hand: 200)
    @product.update!(track_inventory_item: track, hook_inventory_item: hook, bracket_inventory_item: bracket)

    assert_difference("QuoteRequest.count", 1) do
      post add_line_b2b_cart_url, params: {
        line: {
          product_id: @product.id,
          location_name: "Bedroom",
          width_mm: 3830,
          ceiling_drop_mm: 2410,
          opening_type: "single_open",
          finished_floor_mode: "just_off_floor",
          track_selected: "M",
          fixing: "TF",
          quantity: 2
        }
      }
    end
    assert_redirected_to b2b_cart_url

    draft_cart = QuoteRequest.order(:id).last
    assert_no_difference("QuoteRequest.count") do
      post checkout_b2b_cart_url, params: {
        checkout: {
          pickup_method: "delivery"
        }
      }
    end

    created = draft_cart.reload
    assert_equal 1, created.quote_items.first.quantity
    assert_equal 28, hook.reload.on_hand
  end

  test "insufficient stock blocks add to cart" do
    sign_in users(:customer)
    track = InventoryItem.create!(name: "Track", component_type: :track, on_hand: 0)
    hook = InventoryItem.create!(name: "Hook", component_type: :hook, on_hand: 0)
    bracket = InventoryItem.create!(name: "Bracket", component_type: :bracket, on_hand: 0)
    @product.update!(track_inventory_item: track, hook_inventory_item: hook, bracket_inventory_item: bracket)

    post add_line_b2b_cart_url, params: {
      line: {
        product_id: @product.id,
        width_mm: 3830,
        ceiling_drop_mm: 2410,
        opening_type: "single_open",
        finished_floor_mode: "just_off_floor",
        track_selected: "M",
        fixing: "TF",
        quantity: 1
      }
    }

    assert_redirected_to b2b_shop_product_url(@product)
    assert_match(/insufficient stock/i, flash[:alert])
  end

  test "add to cart rejects products with no matrix price" do
    sign_in users(:customer)
    matrixless_product = products(:blackout_panel)
    matrixless_product.update!(
      active: true,
      pricing_channel: "b2b",
      product_type: "Unmapped Curtain",
      style_name: "S Wave"
    )

    post add_line_b2b_cart_url, params: {
      line: {
        product_id: matrixless_product.id,
        width_mm: 3830,
        ceiling_drop_mm: 2410,
        opening_type: "single_open",
        finished_floor_mode: "just_off_floor",
        track_selected: "M",
        fixing: "TF",
        quantity: 1
      }
    }

    assert_redirected_to b2b_shop_product_url(matrixless_product)
    assert_match(/No matrix price is available for this product and size/i, flash[:alert])
  end

  test "checkout form uses submit loading state wiring" do
    sign_in users(:customer)

    post add_line_b2b_cart_url, params: {
      line: {
        product_id: @product.id,
        location_name: "Living Room",
        width_mm: 2500,
        ceiling_drop_mm: 2200,
        opening_type: "single_open",
        finished_floor_mode: "just_off_floor",
        track_selected: "M",
        fixing: "TF",
        quantity: 1
      }
    }
    assert_redirected_to b2b_cart_url

    get b2b_cart_url
    assert_response :success
    assert_select "form[data-controller='submit-state']"
    assert_select "button[data-submit-state-target='button']"
    assert_select "span[data-submit-state-target='label']", text: "Submit order"
    assert_select "span[data-submit-state-target='spinner']"
  end

  test "b2b customer can add different products across shopping steps without cookie overflow" do
    sign_in users(:customer)

    second_product = products(:blackout_panel)
    second_product.update!(
      active: true,
      pricing_channel: "b2b",
      product_type: "Sheer Curtain",
      style_name: "S Wave"
    )

    post add_line_b2b_cart_url, params: {
      line: {
        product_id: @product.id,
        location_name: "Living Room",
        width_mm: 2500,
        ceiling_drop_mm: 2200,
        opening_type: "single_open",
        finished_floor_mode: "just_off_floor",
        track_selected: "M",
        fixing: "TF",
        quantity: 1
      }
    }
    assert_redirected_to b2b_cart_url
    first_cookie_size = cookies["_curtain_b2b_quote_session"].to_s.bytesize

    get b2b_shop_url
    assert_response :success

    post add_line_b2b_cart_url, params: {
      line: {
        product_id: second_product.id,
        location_name: "Bedroom",
        width_mm: 2800,
        ceiling_drop_mm: 2300,
        opening_type: "single_open",
        finished_floor_mode: "just_off_floor",
        track_selected: "M",
        fixing: "TF",
        quantity: 1
      }
    }
    assert_redirected_to b2b_cart_url

    draft_cart = users(:customer).quote_requests.where(status: :order_processing, submitted_at: nil).order(:id).last
    assert_not_nil draft_cart
    assert_equal 2, draft_cart.quote_items.count
    assert_equal [ @product.id, second_product.id ].sort, draft_cart.quote_items.order(:id).pluck(:product_id).sort

    second_cookie_size = cookies["_curtain_b2b_quote_session"].to_s.bytesize
    assert_operator second_cookie_size, :<, 4096
    assert_operator(second_cookie_size - first_cookie_size, :<, 512)
  end

  test "adding the same product again keeps cart stable" do
    sign_in users(:customer)

    post add_line_b2b_cart_url, params: {
      line: {
        product_id: @product.id,
        location_name: "Living Room",
        width_mm: 2500,
        ceiling_drop_mm: 2200,
        opening_type: "single_open",
        finished_floor_mode: "just_off_floor",
        track_selected: "M",
        fixing: "TF",
        quantity: 1
      }
    }
    assert_redirected_to b2b_cart_url

    post add_line_b2b_cart_url, params: {
      line: {
        product_id: @product.id,
        location_name: "Study",
        width_mm: 2600,
        ceiling_drop_mm: 2100,
        opening_type: "single_open",
        finished_floor_mode: "just_off_floor",
        track_selected: "M",
        fixing: "TF",
        quantity: 1
      }
    }
    assert_redirected_to b2b_cart_url

    draft_cart = users(:customer).quote_requests.where(status: :order_processing, submitted_at: nil).order(:id).last
    assert_not_nil draft_cart
    assert_equal 2, draft_cart.quote_items.count
    assert_equal [ @product.id ], draft_cart.quote_items.distinct.pluck(:product_id)
  end
end
