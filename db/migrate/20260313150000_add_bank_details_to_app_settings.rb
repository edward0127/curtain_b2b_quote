class AddBankDetailsToAppSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :app_settings, :bank_account_name, :string
    add_column :app_settings, :bank_name, :string
    add_column :app_settings, :bank_bsb, :string
    add_column :app_settings, :bank_account_number, :string
  end
end
