class AddPublicFooterTaglineToAppSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :app_settings, :public_footer_tagline, :text
  end
end
