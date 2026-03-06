class AddHomeAndBuildersEditorContentToAppSettings < ActiveRecord::Migration[8.1]
  def change
    change_table :app_settings, bulk: true do |t|
      t.text :home_page_published_json
      t.text :home_page_draft_json
      t.text :builders_page_published_json
      t.text :builders_page_draft_json
    end
  end
end
