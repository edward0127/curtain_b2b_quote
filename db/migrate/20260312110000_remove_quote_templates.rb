class RemoveQuoteTemplates < ActiveRecord::Migration[8.1]
  def up
    remove_foreign_key :quote_requests, :quote_templates if foreign_key_exists?(:quote_requests, :quote_templates)
    remove_column :quote_requests, :quote_template_id if column_exists?(:quote_requests, :quote_template_id)
    drop_table :quote_templates if table_exists?(:quote_templates)
  end

  def down
    return if table_exists?(:quote_templates) && column_exists?(:quote_requests, :quote_template_id)

    create_table :quote_templates do |t|
      t.string :name, null: false
      t.string :heading, null: false
      t.text :intro
      t.text :terms
      t.text :footer
      t.boolean :default_template, null: false, default: false
      t.timestamps
    end unless table_exists?(:quote_templates)

    add_index :quote_templates, :name, unique: true unless index_exists?(:quote_templates, :name)

    unless column_exists?(:quote_requests, :quote_template_id)
      add_column :quote_requests, :quote_template_id, :bigint
    end

    default_template_id = select_value("SELECT id FROM quote_templates WHERE default_template = 1 ORDER BY id ASC LIMIT 1")
    if default_template_id.blank?
      execute <<~SQL
        INSERT INTO quote_templates (name, heading, intro, terms, footer, default_template, created_at, updated_at)
        VALUES (
          'standard',
          'Curtain Order / Invoice',
          'Thank you for your enquiry. This order includes all requested lines.',
          'Order valid for 14 days unless otherwise stated.',
          'Please contact us for any requested changes or delivery updates.',
          1,
          CURRENT_TIMESTAMP,
          CURRENT_TIMESTAMP
        )
      SQL
      default_template_id = select_value("SELECT id FROM quote_templates ORDER BY id ASC LIMIT 1")
    end

    execute("UPDATE quote_requests SET quote_template_id = #{default_template_id.to_i} WHERE quote_template_id IS NULL")
    change_column_null :quote_requests, :quote_template_id, false
    add_index :quote_requests, :quote_template_id unless index_exists?(:quote_requests, :quote_template_id)
    add_foreign_key :quote_requests, :quote_templates unless foreign_key_exists?(:quote_requests, :quote_templates)
  end
end
