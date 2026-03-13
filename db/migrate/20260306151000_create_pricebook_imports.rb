class CreatePricebookImports < ActiveRecord::Migration[8.1]
  def change
    create_table :pricebook_imports do |t|
      t.references :imported_by_user, null: false, foreign_key: { to_table: :users }
      t.string :import_type, null: false, default: "wholesale_j000"
      t.string :source_filename, null: false
      t.integer :status, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :products_updated_count, null: false, default: 0
      t.integer :price_matrix_entries_count, null: false, default: 0
      t.integer :track_price_tiers_count, null: false, default: 0
      t.text :log_output
      t.text :error_message

      t.timestamps
    end

    add_index :pricebook_imports, :created_at
  end
end
