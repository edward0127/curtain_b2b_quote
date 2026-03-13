class AddOrderWorkflowFieldsToQuotes < ActiveRecord::Migration[8.1]
  def change
    add_column :quote_requests, :customer_mode, :integer, null: false, default: 0
    add_column :quote_requests, :customer_name, :string
    add_column :quote_requests, :company_name, :string
    add_column :quote_requests, :customer_email, :string
    add_column :quote_requests, :customer_phone, :string
    add_column :quote_requests, :delivery_address, :text
    add_column :quote_requests, :billing_address, :text
    add_column :quote_requests, :pickup_method, :integer, null: false, default: 0
    add_reference :quote_requests, :created_by_user, foreign_key: { to_table: :users }
    add_column :quote_requests, :submitted_at, :datetime
    add_column :quote_requests, :ready_for_pick_up_at, :datetime
    add_column :quote_requests, :completed_at, :datetime
    add_column :quote_requests, :cancelled_at, :datetime

    change_table :quote_items, bulk: true do |t|
      t.string :location_name
      t.string :track_selected
      t.string :fixing
      t.integer :opening_type
      t.string :opening_code
      t.integer :width_mm
      t.integer :ceiling_drop_mm
      t.integer :finished_floor_mode
      t.integer :factory_drop_mm
      t.string :material_name
      t.string :material_number
      t.string :lv_name
      t.string :high_temp_custom
      t.text :width_notes
      t.boolean :wand_required
      t.integer :wand_quantity, null: false, default: 0
      t.integer :end_cap_quantity, null: false, default: 0
      t.integer :stopper_quantity, null: false, default: 0
      t.integer :wand_hook_quantity, null: false, default: 0
      t.decimal :curtain_price, precision: 12, scale: 2, null: false, default: 0
      t.decimal :track_price, precision: 12, scale: 2, null: false, default: 0
      t.string :hooks_display
      t.integer :hooks_total, null: false, default: 0
      t.integer :brackets_total, null: false, default: 0
      t.integer :track_metres_required, null: false, default: 0
    end
  end
end
