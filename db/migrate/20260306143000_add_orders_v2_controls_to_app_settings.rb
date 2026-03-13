class AddOrdersV2ControlsToAppSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :app_settings, :orders_v2_enabled, :boolean, null: false, default: false
    add_column :app_settings, :pickup_address_default, :string, null: false, default: "1/73 Darvall street, Donvale, 3111"
    add_column :app_settings, :delivery_note_default, :string, null: false, default: "Delivery 2 business days"
  end
end
