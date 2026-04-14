require "test_helper"

class Admin::PricebookImportsControllerTest < ActionDispatch::IntegrationTest
  include ActionDispatch::TestProcess::FixtureFile

  test "admin can view imports index" do
    sign_in users(:admin)

    get admin_pricebook_imports_url
    assert_response :success
    assert_includes @response.body, "Curtain Pricing"
    assert_includes @response.body, "Legacy track-tier history is retained automatically"
    assert_not_includes @response.body, "Dormant Track Tiers"
  end

  test "admin sees april 2026 workbook guidance on new import page" do
    sign_in users(:admin)

    get new_admin_pricebook_import_url
    assert_response :success
    assert_includes @response.body, "April 2026 layout"
    assert_includes @response.body, "update values only"
    assert_includes @response.body, "legacy track-tier history"
  end

  test "admin can upload and import curtain pricing workbook" do
    sign_in users(:admin)

    uploaded = fixture_file_upload(
      "pricing_april_2026.xlsx",
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      :binary
    )

    assert_difference("PricebookImport.count", 1) do
      post admin_pricebook_imports_url, params: { pricebook_import: { file: uploaded } }
    end

    import = PricebookImport.order(:id).last
    assert_redirected_to admin_pricebook_imports_url
    assert import.succeeded?, "expected succeeded import, got status=#{import.status} error=#{import.error_message}"
    assert_equal Pricebook::CurtainPricingImporter::IMPORT_TYPE, import.import_type
    assert_equal 4, import.products_updated_count
    assert_equal 240, import.price_matrix_entries_count
    assert_equal 0, import.track_price_tiers_count
    follow_redirect!
    assert_includes @response.body, "active Curtain Pricing workbook format"
  end

  test "b2b customer cannot access imports page" do
    sign_in users(:customer)

    get admin_pricebook_imports_url
    assert_redirected_to root_url
  end
end
