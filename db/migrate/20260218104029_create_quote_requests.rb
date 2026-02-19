class CreateQuoteRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :quote_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.decimal :width, precision: 8, scale: 2, null: false
      t.decimal :height, precision: 8, scale: 2, null: false
      t.integer :quantity, null: false, default: 1
      t.text :notes
      t.integer :status, null: false, default: 0

      t.timestamps
    end
  end
end
