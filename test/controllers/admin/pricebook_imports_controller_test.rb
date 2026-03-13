require "test_helper"

class Admin::PricebookImportsControllerTest < ActionDispatch::IntegrationTest
  include ActionDispatch::TestProcess::FixtureFile

  test "admin can view imports index" do
    sign_in users(:admin)

    get admin_pricebook_imports_url
    assert_response :success
  end

  test "admin can upload and import wholesale j000 workbook" do
    sign_in users(:admin)

    uploaded = fixture_file_upload(
      "wholesale_j000.xlsx",
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      :binary
    )

    assert_difference("PricebookImport.count", 1) do
      post admin_pricebook_imports_url, params: { pricebook_import: { file: uploaded } }
    end

    import = PricebookImport.order(:id).last
    assert_redirected_to admin_pricebook_imports_url
    assert import.succeeded?, "expected succeeded import, got status=#{import.status} error=#{import.error_message}"
    assert_operator import.price_matrix_entries_count, :>, 0
    assert_operator import.track_price_tiers_count, :>, 0
  end

  test "b2b customer cannot access imports page" do
    sign_in users(:customer)

    get admin_pricebook_imports_url
    assert_redirected_to root_url
  end
end
