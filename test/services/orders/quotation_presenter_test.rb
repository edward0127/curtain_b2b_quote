require "test_helper"

class Orders::QuotationPresenterTest < ActiveSupport::TestCase
  test "track column is blank when item uses explicit no track" do
    quote_item = quote_items(:one_line_one)
    quote_item.update!(track_selected: "none", width_mm: 1205, ceiling_drop_mm: 2000)

    presenter = Orders::QuotationPresenter.new(quote_item.quote_request)

    assert_equal "", presenter.rows.first[:track]
  end

  test "bank details use app settings when configured" do
    AppSetting.current.update!(
      bank_account_name: "Light Vue Pty Ltd",
      bank_name: "ANZ",
      bank_bsb: "013456",
      bank_account_number: "123456789"
    )

    presenter = Orders::QuotationPresenter.new(quote_items(:one_line_one).quote_request)

    assert_equal "Light Vue Pty Ltd", presenter.bank_details[:account_name]
    assert_equal "ANZ", presenter.bank_details[:bank_name]
    assert_equal "013456", presenter.bank_details[:bsb]
    assert_equal "123456789", presenter.bank_details[:account_number]
  end
end
