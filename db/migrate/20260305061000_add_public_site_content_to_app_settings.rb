class AddPublicSiteContentToAppSettings < ActiveRecord::Migration[8.1]
  def change
    change_table :app_settings, bulk: true do |t|
      t.string :public_heading_font
      t.string :public_body_font

      t.string :public_cta_contact_label
      t.string :public_cta_login_label

      t.string :public_home_hero_image
      t.text :public_home_hero_title
      t.text :public_home_hero_lead
      t.text :public_home_why_title
      t.text :public_home_products_title
      t.text :public_home_contact_title
      t.text :public_home_contact_subtitle

      t.string :public_partners_hero_image
      t.text :public_partners_hero_title
      t.text :public_partners_hero_lead

      t.string :public_builders_hero_image
      t.text :public_builders_hero_title
      t.text :public_builders_hero_lead
    end
  end
end
