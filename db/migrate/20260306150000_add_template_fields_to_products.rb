class AddTemplateFieldsToProducts < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :product_type, :string
    add_column :products, :style_name, :string
    add_column :products, :pricing_channel, :string

    add_index :products, %i[product_type style_name pricing_channel], name: "index_products_on_template_lookup"
  end
end
