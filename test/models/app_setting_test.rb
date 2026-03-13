require "test_helper"

class AppSettingTest < ActiveSupport::TestCase
  test "order workflow defaults are present" do
    setting = AppSetting.current

    assert_equal "1/73 Darvall street, Donvale, 3111", setting.pickup_address_default
    assert_equal "Delivery 2 business days", setting.delivery_note_default
    assert AppSetting.orders_v2_enabled?
  end

  test "orders_v2_enabled is always enabled at runtime" do
    assert AppSetting.orders_v2_enabled?
  end

  test "pickup and delivery defaults are automatically restored when blank" do
    setting = AppSetting.current
    setting.pickup_address_default = ""
    setting.delivery_note_default = ""

    assert setting.valid?
    setting.save!
    setting.reload

    assert_equal "1/73 Darvall street, Donvale, 3111", setting.pickup_address_default
    assert_equal "Delivery 2 business days", setting.delivery_note_default
  end

  test "new shared order settings persist" do
    setting = AppSetting.current
    setting.update!(
      pickup_address_default: "10 Example Rd, Donvale, 3111",
      delivery_note_default: "Dispatch in 48 hours"
    )

    setting.reload
    assert AppSetting.orders_v2_enabled?
    assert_equal "10 Example Rd, Donvale, 3111", setting.pickup_address_default
    assert_equal "Dispatch in 48 hours", setting.delivery_note_default
  end

  test "bank detail settings persist" do
    setting = AppSetting.current
    setting.update!(
      bank_account_name: "Light Vue Pty Ltd",
      bank_name: "ANZ",
      bank_bsb: "013456",
      bank_account_number: "123456789"
    )

    setting.reload
    assert_equal "Light Vue Pty Ltd", setting.bank_account_name
    assert_equal "ANZ", setting.bank_name
    assert_equal "013456", setting.bank_bsb
    assert_equal "123456789", setting.bank_account_number
  end
end
