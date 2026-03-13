require "test_helper"

class Admin::InventoryItemsControllerTest < ActionDispatch::IntegrationTest
  test "admin can view inventory list" do
    sign_in users(:admin)

    get admin_inventory_items_url
    assert_response :success
  end

  test "admin can create inventory item" do
    sign_in users(:admin)

    assert_difference("InventoryItem.count", 1) do
      post admin_inventory_items_url, params: {
        inventory_item: {
          name: "Test Hook",
          component_type: :hook,
          sku: "HOOK-1",
          on_hand: 120,
          active: true
        }
      }
    end

    assert_redirected_to admin_inventory_items_url
  end

  test "admin can adjust stock by set increase and decrease" do
    sign_in users(:admin)
    item = InventoryItem.create!(name: "Track Roll", component_type: :track, on_hand: 10)

    patch adjust_stock_admin_inventory_item_url(item), params: { mode: "set", amount: 50 }
    assert_redirected_to admin_inventory_items_url
    assert_equal 50, item.reload.on_hand

    patch adjust_stock_admin_inventory_item_url(item), params: { mode: "increase", amount: 5 }
    assert_equal 55, item.reload.on_hand

    patch adjust_stock_admin_inventory_item_url(item), params: { mode: "decrease", amount: 12 }
    assert_equal 43, item.reload.on_hand
  end

  test "b2b customer cannot access inventory admin" do
    sign_in users(:customer)

    get admin_inventory_items_url
    assert_redirected_to root_url
  end
end
