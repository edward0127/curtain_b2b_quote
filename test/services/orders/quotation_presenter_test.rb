require "test_helper"

class Orders::QuotationPresenterTest < ActiveSupport::TestCase
  test "new active records do not expose legacy track details" do
    quote_item = quote_items(:one_line_one)
    quote_item.update!(width_mm: 3830, ceiling_drop_mm: 2410, curtain_price: 440, track_price: 0, track_metres_required: 0)
    presenter = Orders::QuotationPresenter.new(quote_item.quote_request)

    assert_not presenter.show_track_details?
    assert_equal "OW", presenter.rows.first[:opening]
    assert_equal "", presenter.rows.first[:track]
  end

  test "legacy records still expose track details" do
    quote_item = quote_items(:one_line_one)
    quote_item.update!(width_mm: 3830, ceiling_drop_mm: 2410, track_selected: "M", track_price: 130, track_metres_required: 4)

    presenter = Orders::QuotationPresenter.new(quote_item.quote_request)

    assert presenter.show_track_details?
    assert_equal "M", presenter.rows.first[:track]
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
