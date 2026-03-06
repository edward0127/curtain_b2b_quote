class AddPartnersEditorContentToAppSettings < ActiveRecord::Migration[8.1]
  def change
    change_table :app_settings, bulk: true do |t|
      t.text :partners_page_published_json
      t.text :partners_page_draft_json
    end
  end
end
