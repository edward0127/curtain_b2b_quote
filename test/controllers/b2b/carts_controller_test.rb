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
    assert_redirected_to b2b_cart_url

    assert_difference("QuoteRequest.count", 1) do
      assert_difference("ActionMailer::Base.deliveries.size", 2) do
        post checkout_b2b_cart_url, params: {
          checkout: {
            pickup_method: "delivery",
            customer_reference: "B2B-PO-900"
          }
        }
      end
    end

    created = QuoteRequest.order(:id).last
    assert_redirected_to quote_request_url(created)
    assert_equal "order_processing", created.status
    assert_equal users(:customer).email, created.customer_email
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
    assert_redirected_to b2b_cart_url

    assert_difference("QuoteRequest.count", 1) do
      post checkout_b2b_cart_url, params: {
        checkout: {
          pickup_method: "delivery"
        }
      }
    end

    created = QuoteRequest.order(:id).last
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
end
