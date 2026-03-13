# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_03_13_150000) do
  create_table "app_settings", force: :cascade do |t|
    t.string "app_host"
    t.integer "app_port"
    t.string "app_protocol"
    t.string "bank_account_name"
    t.string "bank_account_number"
    t.string "bank_bsb"
    t.string "bank_name"
    t.text "builders_page_draft_json"
    t.text "builders_page_published_json"
    t.datetime "created_at", null: false
    t.string "delivery_note_default", default: "Delivery 2 business days", null: false
    t.text "home_page_draft_json"
    t.text "home_page_published_json"
    t.string "mail_from_email"
    t.string "mailgun_domain"
    t.string "mailgun_smtp_address"
    t.string "mailgun_smtp_password"
    t.integer "mailgun_smtp_port"
    t.string "mailgun_smtp_username"
    t.boolean "orders_v2_enabled", default: false, null: false
    t.text "partners_page_draft_json"
    t.text "partners_page_published_json"
    t.string "pickup_address_default", default: "1/73 Darvall street, Donvale, 3111", null: false
    t.string "public_body_font"
    t.string "public_builders_hero_image"
    t.text "public_builders_hero_lead"
    t.text "public_builders_hero_title"
    t.string "public_cta_contact_label"
    t.string "public_cta_login_label"
    t.text "public_footer_tagline"
    t.string "public_heading_font"
    t.text "public_home_contact_subtitle"
    t.text "public_home_contact_title"
    t.string "public_home_hero_image"
    t.text "public_home_hero_lead"
    t.text "public_home_hero_title"
    t.text "public_home_products_title"
    t.text "public_home_why_title"
    t.string "public_partners_hero_image"
    t.text "public_partners_hero_lead"
    t.text "public_partners_hero_title"
    t.string "quote_receiver_email"
    t.datetime "updated_at", null: false
  end

  create_table "inventory_items", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "component_type", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "notes"
    t.integer "on_hand", default: 0, null: false
    t.string "sku"
    t.datetime "updated_at", null: false
    t.index ["component_type"], name: "index_inventory_items_on_component_type"
    t.index ["sku"], name: "index_inventory_items_on_sku", unique: true
  end

  create_table "jobs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "job_number", null: false
    t.text "notes"
    t.integer "quote_request_id", null: false
    t.date "scheduled_on"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["job_number"], name: "index_jobs_on_job_number", unique: true
    t.index ["quote_request_id"], name: "index_jobs_on_quote_request_id", unique: true
    t.index ["user_id"], name: "index_jobs_on_user_id"
  end

  create_table "price_matrix_entries", force: :cascade do |t|
    t.string "channel", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "AUD", null: false
    t.integer "drop_band_max_mm", null: false
    t.integer "drop_band_min_mm", null: false
    t.decimal "price", precision: 12, scale: 2, default: "0.0", null: false
    t.string "product_name", null: false
    t.string "source_version"
    t.string "style_name", default: "", null: false
    t.datetime "updated_at", null: false
    t.integer "width_band_max_mm", null: false
    t.integer "width_band_min_mm", null: false
    t.index ["channel", "product_name", "style_name", "width_band_min_mm", "width_band_max_mm", "drop_band_min_mm", "drop_band_max_mm"], name: "index_price_matrix_entries_on_lookup_key", unique: true
  end

  create_table "pricebook_imports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.datetime "finished_at"
    t.string "import_type", default: "wholesale_j000", null: false
    t.integer "imported_by_user_id", null: false
    t.text "log_output"
    t.integer "price_matrix_entries_count", default: 0, null: false
    t.integer "products_updated_count", default: 0, null: false
    t.string "source_filename", null: false
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.integer "track_price_tiers_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_pricebook_imports_on_created_at"
    t.index ["imported_by_user_id"], name: "index_pricebook_imports_on_imported_by_user_id"
  end

  create_table "pricing_rules", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.integer "adjustment_type", default: 0, null: false
    t.decimal "adjustment_value", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.decimal "max_area", precision: 8, scale: 2
    t.integer "max_quantity"
    t.decimal "min_area", precision: 8, scale: 2
    t.integer "min_quantity"
    t.string "name", null: false
    t.integer "priority", default: 100, null: false
    t.integer "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_pricing_rules_on_product_id"
  end

  create_table "products", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.decimal "base_price", precision: 10, scale: 2, default: "0.0", null: false
    t.integer "bracket_inventory_item_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "end_cap_inventory_item_id"
    t.integer "hook_inventory_item_id"
    t.string "name", null: false
    t.string "pricing_channel"
    t.integer "pricing_mode", default: 0, null: false
    t.string "product_type"
    t.string "sku"
    t.integer "stopper_inventory_item_id"
    t.string "style_name"
    t.integer "track_inventory_item_id"
    t.datetime "updated_at", null: false
    t.integer "wand_hook_inventory_item_id"
    t.integer "wand_inventory_item_id"
    t.index ["bracket_inventory_item_id"], name: "index_products_on_bracket_inventory_item_id"
    t.index ["end_cap_inventory_item_id"], name: "index_products_on_end_cap_inventory_item_id"
    t.index ["hook_inventory_item_id"], name: "index_products_on_hook_inventory_item_id"
    t.index ["product_type", "style_name", "pricing_channel"], name: "index_products_on_template_lookup"
    t.index ["sku"], name: "index_products_on_sku", unique: true
    t.index ["stopper_inventory_item_id"], name: "index_products_on_stopper_inventory_item_id"
    t.index ["track_inventory_item_id"], name: "index_products_on_track_inventory_item_id"
    t.index ["wand_hook_inventory_item_id"], name: "index_products_on_wand_hook_inventory_item_id"
    t.index ["wand_inventory_item_id"], name: "index_products_on_wand_inventory_item_id"
  end

  create_table "quote_items", force: :cascade do |t|
    t.string "applied_rule_names"
    t.decimal "area_sqm", precision: 10, scale: 3, default: "0.0", null: false
    t.integer "brackets_total", default: 0, null: false
    t.integer "ceiling_drop_mm"
    t.datetime "created_at", null: false
    t.decimal "curtain_price", precision: 12, scale: 2, default: "0.0", null: false
    t.string "description"
    t.integer "end_cap_quantity", default: 0, null: false
    t.integer "factory_drop_mm"
    t.integer "finished_floor_mode"
    t.string "fixing"
    t.decimal "height", precision: 8, scale: 2
    t.string "high_temp_custom"
    t.string "hooks_display"
    t.integer "hooks_total", default: 0, null: false
    t.integer "line_position", default: 1, null: false
    t.decimal "line_total", precision: 12, scale: 2, default: "0.0", null: false
    t.string "location_name"
    t.string "lv_name"
    t.string "material_name"
    t.string "material_number"
    t.string "opening_code"
    t.integer "opening_type"
    t.integer "product_id", null: false
    t.integer "quantity", default: 1, null: false
    t.integer "quote_request_id", null: false
    t.integer "stopper_quantity", default: 0, null: false
    t.integer "track_metres_required", default: 0, null: false
    t.decimal "track_price", precision: 12, scale: 2, default: "0.0", null: false
    t.string "track_selected"
    t.decimal "unit_price", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.integer "wand_hook_quantity", default: 0, null: false
    t.integer "wand_quantity", default: 0, null: false
    t.boolean "wand_required"
    t.decimal "width", precision: 8, scale: 2
    t.integer "width_mm"
    t.text "width_notes"
    t.index ["product_id"], name: "index_quote_items_on_product_id"
    t.index ["quote_request_id"], name: "index_quote_items_on_quote_request_id"
  end

  create_table "quote_requests", force: :cascade do |t|
    t.datetime "approved_at"
    t.text "billing_address"
    t.datetime "cancelled_at"
    t.string "company_name"
    t.datetime "completed_at"
    t.datetime "converted_to_job_at"
    t.datetime "created_at", null: false
    t.integer "created_by_user_id"
    t.string "currency", default: "AUD", null: false
    t.string "customer_email"
    t.integer "customer_mode", default: 0, null: false
    t.string "customer_name"
    t.string "customer_phone"
    t.string "customer_reference"
    t.text "delivery_address"
    t.decimal "height", precision: 8, scale: 2, null: false
    t.text "notes"
    t.integer "pickup_method", default: 0, null: false
    t.datetime "priced_at"
    t.integer "quantity", default: 1, null: false
    t.string "quote_number", null: false
    t.datetime "ready_for_pick_up_at"
    t.datetime "rejected_at"
    t.datetime "reviewed_at"
    t.datetime "sent_at"
    t.integer "status", default: 0, null: false
    t.datetime "submitted_at"
    t.decimal "subtotal", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "total", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.date "valid_until"
    t.decimal "width", precision: 8, scale: 2, null: false
    t.index ["created_by_user_id"], name: "index_quote_requests_on_created_by_user_id"
    t.index ["quote_number"], name: "index_quote_requests_on_quote_number", unique: true
    t.index ["user_id"], name: "index_quote_requests_on_user_id"
  end

  create_table "track_price_tiers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "currency", default: "AUD", null: false
    t.decimal "price", precision: 12, scale: 2, default: "0.0", null: false
    t.string "source_version"
    t.string "track_name", null: false
    t.datetime "updated_at", null: false
    t.integer "width_band_max_mm", null: false
    t.integer "width_band_min_mm", null: false
    t.index ["track_name", "width_band_min_mm", "width_band_max_mm"], name: "index_track_price_tiers_on_lookup_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "jobs", "quote_requests"
  add_foreign_key "jobs", "users"
  add_foreign_key "pricebook_imports", "users", column: "imported_by_user_id"
  add_foreign_key "pricing_rules", "products"
  add_foreign_key "products", "inventory_items", column: "bracket_inventory_item_id"
  add_foreign_key "products", "inventory_items", column: "end_cap_inventory_item_id"
  add_foreign_key "products", "inventory_items", column: "hook_inventory_item_id"
  add_foreign_key "products", "inventory_items", column: "stopper_inventory_item_id"
  add_foreign_key "products", "inventory_items", column: "track_inventory_item_id"
  add_foreign_key "products", "inventory_items", column: "wand_hook_inventory_item_id"
  add_foreign_key "products", "inventory_items", column: "wand_inventory_item_id"
  add_foreign_key "quote_items", "products"
  add_foreign_key "quote_items", "quote_requests"
  add_foreign_key "quote_requests", "users"
  add_foreign_key "quote_requests", "users", column: "created_by_user_id"
end
