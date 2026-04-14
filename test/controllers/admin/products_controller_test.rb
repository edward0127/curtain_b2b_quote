require "test_helper"

class Admin::ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @product = products(:sheer_panel)
    @product.update!(
      product_type: "Sheer Curtain",
      style_name: "S Wave",
      pricing_channel: "b2b",
      base_price: 0
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

  test "products index shows pricing label instead of base price amount" do
    sign_in users(:admin)

    get admin_products_url
    assert_response :success
    assert_select "th", text: "Channel"
    assert_select "th", text: "Pricing"
    assert_select "th", text: "Base Price", count: 0
    assert_select "td .status-pill--b2b", text: "B2B"
    assert_select "td", text: "Matrix pricing"
    assert_select "a", text: "Preview price"
    assert_no_match(/\bAUD\s+0\.00\b/, @response.body)
  end

  test "products index shows not set channel when pricing channel is missing" do
    sign_in users(:admin)

    get admin_products_url
    assert_response :success
    assert_select "td .status-pill--not_set", text: "Not set"
  end

  test "admin can create product with pricing channel and matrix template fields" do
    sign_in users(:admin)

    assert_difference("Product.count", 1) do
      post admin_products_url, params: {
        product: {
          name: "Manual Matrix Product",
          sku: "MANUAL-MATRIX-001",
          base_price: 0,
          pricing_mode: "per_unit",
          pricing_channel: "b2c",
          product_type: "Sheer Curtain",
          style_name: "S Wave",
          active: true
        }
      }
    end

    created = Product.order(:id).last
    assert_equal "b2c", created.pricing_channel
    assert_equal "Sheer Curtain", created.product_type
    assert_equal "S Wave", created.style_name
  end

  test "product form explains not set channel and base price usage" do
    sign_in users(:admin)

    get new_admin_product_url
    assert_response :success
    assert_includes @response.body, "\"Not set\" is for legacy/manual products"
    assert_includes @response.body, "For matrix-priced products, live pricing comes from imported matrix rows."
    assert_includes @response.body, "New active orders ignore separate track pricing and stock deduction."
  end

  test "admin can update product pricing channel and matrix fields" do
    sign_in users(:admin)

    patch admin_product_url(@product), params: {
      product: {
        pricing_channel: "b2c",
        product_type: "Blockout Curtain",
        style_name: "Pinch Pleat"
      }
    }

    assert_redirected_to admin_product_url(@product)
    @product.reload
    assert_equal "b2c", @product.pricing_channel
    assert_equal "Blockout Curtain", @product.product_type
    assert_equal "Pinch Pleat", @product.style_name
  end

  test "product with pricing channel requires matrix type and style" do
    sign_in users(:admin)

    assert_no_difference("Product.count") do
      post admin_products_url, params: {
        product: {
          name: "Invalid Matrix Product",
          sku: "INVALID-MATRIX-001",
          base_price: 0,
          pricing_mode: "per_unit",
          pricing_channel: "b2c",
          active: true
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes @response.body, "Product type can&#39;t be blank"
    assert_includes @response.body, "Style name can&#39;t be blank"
  end

  test "admin can preview matrix pricing" do
    sign_in users(:admin)

    get preview_price_admin_product_url(@product), params: {
      preview: {
        customer_mode: "b2b",
        width_mm: "3830",
        drop_mm: "2410"
      }
    }

    assert_response :success
    assert_includes @response.body, "Line total"
    assert_includes @response.body, "AUD 274.40"
    assert_select "select[name='preview[track_selected]']", count: 0
    assert_no_match(/Track price/, @response.body)
  end

  test "preview defaults customer mode to product pricing channel" do
    sign_in users(:admin)
    @product.update!(pricing_channel: "b2c")

    get preview_price_admin_product_url(@product)
    assert_response :success
    assert_select "select[name='preview[customer_mode]'] option[selected][value='b2c']", text: "B2C"
  end

  test "preview shows friendly no matrix error when curtain price not found" do
    sign_in users(:admin)

    get preview_price_admin_product_url(@product), params: {
      preview: {
        customer_mode: "b2b",
        width_mm: "99999",
        drop_mm: "99999"
      }
    }

    assert_response :success
    assert_includes @response.body, "No matrix price found for these dimensions"
  end

  test "preview validates width and drop positive integers" do
    sign_in users(:admin)

    get preview_price_admin_product_url(@product), params: {
      preview: {
        customer_mode: "b2b",
        width_mm: "0",
        drop_mm: "-1"
      }
    }

    assert_response :success
    assert_includes @response.body, "Width and drop must be positive integers."
  end

  test "preview indicates when selected customer mode has no imported matrix rows" do
    sign_in users(:admin)
    PriceMatrixEntry.where(
      channel: "b2c",
      product_name: @product.matrix_lookup_name,
      style_name: @product.style_name
    ).delete_all

    get preview_price_admin_product_url(@product), params: {
      preview: {
        customer_mode: "b2c",
        width_mm: "3830",
        drop_mm: "2410"
      }
    }

    assert_response :success
    assert_includes @response.body, "no B2C matrix rows imported"
  end

  test "admin can update component inventory mappings on product" do
    sign_in users(:admin)

    track_item = InventoryItem.create!(name: "Track Roll A", component_type: :track, on_hand: 120, active: true)
    hook_item = InventoryItem.create!(name: "Hook Pack A", component_type: :hook, on_hand: 400, active: true)
    bracket_item = InventoryItem.create!(name: "Bracket Set A", component_type: :bracket, on_hand: 200, active: true)
    wand_item = InventoryItem.create!(name: "Wand A", component_type: :wand, on_hand: 80, active: true)
    end_cap_item = InventoryItem.create!(name: "End Cap A", component_type: :end_cap, on_hand: 160, active: true)
    stopper_item = InventoryItem.create!(name: "Stopper A", component_type: :stopper, on_hand: 260, active: true)
    wand_hook_item = InventoryItem.create!(name: "Wand Hook A", component_type: :wand_hook, on_hand: 140, active: true)

    patch admin_product_url(@product), params: {
      product: {
        track_inventory_item_id: track_item.id,
        hook_inventory_item_id: hook_item.id,
        bracket_inventory_item_id: bracket_item.id,
        wand_inventory_item_id: wand_item.id,
        end_cap_inventory_item_id: end_cap_item.id,
        stopper_inventory_item_id: stopper_item.id,
        wand_hook_inventory_item_id: wand_hook_item.id
      }
    }

    assert_redirected_to admin_product_url(@product)

    @product.reload
    assert_equal track_item.id, @product.track_inventory_item_id
    assert_equal hook_item.id, @product.hook_inventory_item_id
    assert_equal bracket_item.id, @product.bracket_inventory_item_id
    assert_equal wand_item.id, @product.wand_inventory_item_id
    assert_equal end_cap_item.id, @product.end_cap_inventory_item_id
    assert_equal stopper_item.id, @product.stopper_inventory_item_id
    assert_equal wand_hook_item.id, @product.wand_hook_inventory_item_id
  end

  test "default index hides inactive imported pb templates but still shows other inactive products" do
    sign_in users(:admin)

    archived_imported = Product.create!(
      name: "Archived Imported PB",
      sku: "PB-B2B-ARCHIVED-SHEER-S-WAVE",
      description: "Archived imported template",
      base_price: 0,
      pricing_mode: :per_unit,
      pricing_channel: "b2b",
      product_type: "Sheer Curtain",
      style_name: "S Wave",
      active: false
    )
    inactive_manual = Product.create!(
      name: "Inactive Manual Product",
      sku: "MANUAL-INACTIVE-001",
      description: "Inactive manual product",
      base_price: 10,
      pricing_mode: :per_unit,
      active: false
    )

    get admin_products_url
    assert_response :success
    assert_not_includes @response.body, archived_imported.name
    assert_includes @response.body, inactive_manual.name
    assert_includes @response.body, "Show Archived PB Templates (1)"

    get admin_products_url(show_archived_imported: 1)
    assert_response :success
    assert_includes @response.body, archived_imported.name
    assert_includes @response.body, "preserved for older quotes and orders"
    assert_includes @response.body, "Archived PB template"
  end

  test "product detail page shows channel type and style" do
    sign_in users(:admin)

    get admin_product_url(@product)
    assert_response :success
    assert_includes @response.body, "Channel"
    assert_includes @response.body, "B2B"
    assert_includes @response.body, "Product type"
    assert_includes @response.body, "Sheer Curtain"
    assert_includes @response.body, "Style"
    assert_includes @response.body, "S Wave"
  end

  test "product detail warns when active matrix template has no imported matrix rows" do
    sign_in users(:admin)
    @product.update!(product_type: "Unmapped Curtain", style_name: "S Wave", pricing_channel: "b2b", active: true)

    get admin_product_url(@product)
    assert_response :success
    assert_includes @response.body, "no imported matrix pricing is currently available"
  end

  test "archived imported product detail explains historical preservation" do
    sign_in users(:admin)
    archived_imported = Product.create!(
      name: "Archived Imported PB",
      sku: "PB-B2B-ARCHIVED-SHEER-S-WAVE",
      description: "Archived imported template",
      base_price: 0,
      pricing_mode: :per_unit,
      pricing_channel: "b2b",
      product_type: "Sheer Curtain",
      style_name: "S Wave",
      active: false
    )

    get admin_product_url(archived_imported)
    assert_response :success
    assert_includes @response.body, "preserved for historical quotes and orders"
    assert_includes @response.body, "Legacy track mapping"
  end
end
