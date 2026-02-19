require "test_helper"

class Admin::B2bCustomersControllerTest < ActionDispatch::IntegrationTest
  test "admin can view customer list" do
    sign_in users(:admin)
    get admin_b2b_customers_url
    assert_response :success
  end

  test "admin can create b2b customer" do
    sign_in users(:admin)

    assert_difference("User.b2b_customer.count", 1) do
      post admin_b2b_customers_url, params: {
        user: {
          email: "new.customer@example.com",
          password: "Password123!",
          password_confirmation: "Password123!"
        }
      }
    end

    assert_redirected_to admin_b2b_customers_url
  end

  test "admin can update b2b customer" do
    sign_in users(:admin)
    patch admin_b2b_customer_url(users(:customer)), params: {
      user: { email: "updated.customer@example.com" }
    }
    assert_redirected_to admin_b2b_customers_url
    assert_equal "updated.customer@example.com", users(:customer).reload.email
  end

  test "admin can delete b2b customer" do
    sign_in users(:admin)

    assert_difference("User.b2b_customer.count", -1) do
      delete admin_b2b_customer_url(users(:customer))
    end

    assert_redirected_to admin_b2b_customers_url
  end

  test "b2b customer cannot access admin area" do
    sign_in users(:customer)
    get admin_b2b_customers_url
    assert_redirected_to root_url
  end

  test "requires login" do
    get admin_b2b_customers_url
    assert_redirected_to new_user_session_url
  end

  test "admin cannot edit admin users in b2b controller" do
    sign_in users(:admin)
    get edit_admin_b2b_customer_url(users(:admin))
    assert_response :not_found
  end

  test "admin sees new page" do
    sign_in users(:admin)
    get new_admin_b2b_customer_url
    assert_response :success
  end
end
