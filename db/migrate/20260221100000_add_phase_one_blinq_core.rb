class AddPhaseOneBlinqCore < ActiveRecord::Migration[8.1]
  class MigrationQuoteRequest < ActiveRecord::Base
    self.table_name = "quote_requests"
  end

  class MigrationQuoteItem < ActiveRecord::Base
    self.table_name = "quote_items"
  end

  class MigrationProduct < ActiveRecord::Base
    self.table_name = "products"
  end

  class MigrationQuoteTemplate < ActiveRecord::Base
    self.table_name = "quote_templates"
  end

  def up
    create_table :products do |t|
      t.string :name, null: false
      t.string :sku
      t.text :description
      t.decimal :base_price, precision: 10, scale: 2, null: false, default: 0
      t.integer :pricing_mode, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :products, :sku, unique: true

    create_table :pricing_rules do |t|
      t.references :product, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :priority, null: false, default: 100
      t.boolean :active, null: false, default: true
      t.decimal :min_area, precision: 8, scale: 2
      t.decimal :max_area, precision: 8, scale: 2
      t.integer :min_quantity
      t.integer :max_quantity
      t.integer :adjustment_type, null: false, default: 0
      t.decimal :adjustment_value, precision: 10, scale: 2, null: false, default: 0
      t.timestamps
    end

    create_table :quote_templates do |t|
      t.string :name, null: false
      t.string :heading, null: false
      t.text :intro
      t.text :terms
      t.text :footer
      t.boolean :default_template, null: false, default: false
      t.timestamps
    end
    add_index :quote_templates, :name, unique: true

    add_reference :quote_requests, :quote_template, foreign_key: true
    add_column :quote_requests, :quote_number, :string
    add_column :quote_requests, :customer_reference, :string
    add_column :quote_requests, :currency, :string, default: "AUD", null: false
    add_column :quote_requests, :valid_until, :date
    add_column :quote_requests, :subtotal, :decimal, precision: 12, scale: 2, null: false, default: 0
    add_column :quote_requests, :total, :decimal, precision: 12, scale: 2, null: false, default: 0
    add_column :quote_requests, :reviewed_at, :datetime
    add_column :quote_requests, :priced_at, :datetime
    add_column :quote_requests, :sent_at, :datetime
    add_column :quote_requests, :approved_at, :datetime
    add_column :quote_requests, :rejected_at, :datetime
    add_column :quote_requests, :converted_to_job_at, :datetime
    add_index :quote_requests, :quote_number, unique: true

    create_table :quote_items do |t|
      t.references :quote_request, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :line_position, null: false, default: 1
      t.string :description
      t.decimal :width, precision: 8, scale: 2
      t.decimal :height, precision: 8, scale: 2
      t.integer :quantity, null: false, default: 1
      t.decimal :area_sqm, precision: 10, scale: 3, null: false, default: 0
      t.decimal :unit_price, precision: 10, scale: 2, null: false, default: 0
      t.decimal :line_total, precision: 12, scale: 2, null: false, default: 0
      t.string :applied_rule_names
      t.timestamps
    end

    create_table :jobs do |t|
      t.references :quote_request, null: false, foreign_key: true, index: { unique: true }
      t.references :user, null: false, foreign_key: true
      t.string :job_number, null: false
      t.integer :status, null: false, default: 0
      t.date :scheduled_on
      t.text :notes
      t.timestamps
    end
    add_index :jobs, :job_number, unique: true

    backfill_phase_one_data!

    change_column_null :quote_requests, :quote_template_id, false
    change_column_null :quote_requests, :quote_number, false
  end

  def down
    remove_index :quote_requests, :quote_number
    remove_column :quote_requests, :converted_to_job_at
    remove_column :quote_requests, :rejected_at
    remove_column :quote_requests, :approved_at
    remove_column :quote_requests, :sent_at
    remove_column :quote_requests, :priced_at
    remove_column :quote_requests, :reviewed_at
    remove_column :quote_requests, :total
    remove_column :quote_requests, :subtotal
    remove_column :quote_requests, :valid_until
    remove_column :quote_requests, :currency
    remove_column :quote_requests, :customer_reference
    remove_column :quote_requests, :quote_number
    remove_reference :quote_requests, :quote_template, foreign_key: true

    drop_table :jobs
    drop_table :quote_items
    drop_table :quote_templates
    drop_table :pricing_rules
    drop_table :products
  end

  private

  def backfill_phase_one_data!
    now = Time.current

    default_template = MigrationQuoteTemplate.create!(
      name: "standard",
      heading: "Curtain Quote",
      intro: "Thank you for your enquiry. This quote includes all requested curtain lines.",
      terms: "Quote valid for 14 days. Final pricing is subject to site confirmation.",
      footer: "Please contact us if you have questions about this quote.",
      default_template: true,
      created_at: now,
      updated_at: now
    )

    legacy_product = MigrationProduct.create!(
      name: "Custom Curtain (Legacy)",
      sku: "LEGACY-CURTAIN",
      description: "Auto-created product for quotes submitted before product catalog rollout.",
      base_price: 0,
      pricing_mode: 0,
      active: true,
      created_at: now,
      updated_at: now
    )

    MigrationQuoteRequest.reset_column_information
    MigrationQuoteItem.reset_column_information

    MigrationQuoteRequest.find_each do |quote|
      quote_number = format("Q-%<date>s-%<id>05d", date: quote.created_at.strftime("%Y%m%d"), id: quote.id)
      quantity = [ quote.quantity.to_i, 1 ].max
      area_sqm = ((quote.width.to_d * quote.height.to_d) / 10_000).round(3)

      quote.update_columns(
        quote_number: quote_number,
        quote_template_id: default_template.id,
        valid_until: quote.created_at.to_date + 14.days,
        subtotal: 0,
        total: 0
      )

      MigrationQuoteItem.create!(
        quote_request_id: quote.id,
        product_id: legacy_product.id,
        line_position: 1,
        description: "Legacy imported line item",
        width: quote.width,
        height: quote.height,
        quantity: quantity,
        area_sqm: area_sqm,
        unit_price: 0,
        line_total: 0,
        created_at: now,
        updated_at: now
      )
    end
  end
end
