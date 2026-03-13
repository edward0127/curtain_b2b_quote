class CreatePricingAndInventoryCore < ActiveRecord::Migration[8.1]
  def change
    create_table :price_matrix_entries do |t|
      t.string :channel, null: false
      t.string :product_name, null: false
      t.string :style_name, null: false, default: ""
      t.integer :width_band_min_mm, null: false
      t.integer :width_band_max_mm, null: false
      t.integer :drop_band_min_mm, null: false
      t.integer :drop_band_max_mm, null: false
      t.decimal :price, precision: 12, scale: 2, null: false, default: 0
      t.string :currency, null: false, default: "AUD"
      t.string :source_version

      t.timestamps
    end

    add_index :price_matrix_entries,
              %i[channel product_name style_name width_band_min_mm width_band_max_mm drop_band_min_mm drop_band_max_mm],
              unique: true,
              name: "index_price_matrix_entries_on_lookup_key"

    create_table :track_price_tiers do |t|
      t.string :track_name, null: false
      t.integer :width_band_min_mm, null: false
      t.integer :width_band_max_mm, null: false
      t.decimal :price, precision: 12, scale: 2, null: false, default: 0
      t.string :currency, null: false, default: "AUD"
      t.string :source_version

      t.timestamps
    end

    add_index :track_price_tiers,
              %i[track_name width_band_min_mm width_band_max_mm],
              unique: true,
              name: "index_track_price_tiers_on_lookup_key"

    create_table :inventory_items do |t|
      t.string :name, null: false
      t.string :sku
      t.integer :component_type, null: false
      t.integer :on_hand, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.text :notes

      t.timestamps
    end

    add_index :inventory_items, :sku, unique: true
    add_index :inventory_items, :component_type

    add_reference :products, :track_inventory_item, foreign_key: { to_table: :inventory_items }
    add_reference :products, :hook_inventory_item, foreign_key: { to_table: :inventory_items }
    add_reference :products, :bracket_inventory_item, foreign_key: { to_table: :inventory_items }
    add_reference :products, :wand_inventory_item, foreign_key: { to_table: :inventory_items }
    add_reference :products, :end_cap_inventory_item, foreign_key: { to_table: :inventory_items }
    add_reference :products, :stopper_inventory_item, foreign_key: { to_table: :inventory_items }
    add_reference :products, :wand_hook_inventory_item, foreign_key: { to_table: :inventory_items }
  end
end
