require "test_helper"

class B2b::ShopControllerTest < ActionDispatch::IntegrationTest
  setup do
    products(:sheer_panel).update!(
      pricing_channel: "b2b",
      product_type: "Sheer Curtain",
      style_name: "S Wave",
      active: true
    )
    products(:blackout_panel).update!(
      pricing_channel: "b2c",
      product_type: "Blockout Curtain",
      style_name: "S Wave",
      active: true
    )
    @matrixless_b2b = Product.create!(
      name: "Unmapped B2B Product",
      sku: "UNMAPPED-B2B-001",
      base_price: 0,
      pricing_mode: :per_unit,
      pricing_channel: "b2b",
      product_type: "Unmapped Curtain",
      style_name: "S Wave",
      active: true
    )

    PriceMatrixEntry.where(channel: "b2b", product_name: "Sheer Curtain", style_name: "S Wave").delete_all
    PriceMatrixEntry.create!(
      channel: "b2b",
      product_name: "Sheer Curtain",
      style_name: "S Wave",
      width_band_min_mm: 0,
      width_band_max_mm: 6000,
      drop_band_min_mm: 0,
      drop_band_max_mm: 4000,
      price: 274.4,
      currency: "AUD"
    )
  end

  test "b2b customer can view shop index and product config page" do
    sign_in users(:customer)

    get b2b_shop_url
    assert_response :success
    assert_includes @response.body, "Order Products"
    assert_includes @response.body, products(:sheer_panel).name
    assert_not_includes @response.body, products(:blackout_panel).name
    assert_not_includes @response.body, @matrixless_b2b.name

    get b2b_shop_product_url(products(:sheer_panel))
    assert_response :success
    assert_includes @response.body, products(:sheer_panel).name
    assert_select "select[name='line[track_selected]']", count: 0
    assert_no_match(/Track option/, @response.body)
  end

  test "b2b shop show blocks non-b2b templates" do
    sign_in users(:customer)

    get b2b_shop_product_url(products(:blackout_panel))
    assert_response :not_found
  end

  test "b2b shop hides and blocks matrix-unready b2b templates" do
    sign_in users(:customer)

    get b2b_shop_url
    assert_response :success
    assert_not_includes @response.body, @matrixless_b2b.name

    get b2b_shop_product_url(@matrixless_b2b)
    assert_response :not_found
  end

  test "admin cannot access b2b shop pages" do
    sign_in users(:admin)

    get b2b_shop_url
    assert_redirected_to root_url
  end
end
