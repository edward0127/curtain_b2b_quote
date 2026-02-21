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

ActiveRecord::Schema[8.1].define(version: 2026_02_21_100000) do
  create_table "app_settings", force: :cascade do |t|
    t.string "app_host"
    t.integer "app_port"
    t.string "app_protocol"
    t.datetime "created_at", null: false
    t.string "mail_from_email"
    t.string "mailgun_domain"
    t.string "mailgun_smtp_address"
    t.string "mailgun_smtp_password"
    t.integer "mailgun_smtp_port"
    t.string "mailgun_smtp_username"
    t.string "quote_receiver_email"
    t.datetime "updated_at", null: false
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
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "pricing_mode", default: 0, null: false
    t.string "sku"
    t.datetime "updated_at", null: false
    t.index ["sku"], name: "index_products_on_sku", unique: true
  end

  create_table "quote_items", force: :cascade do |t|
    t.string "applied_rule_names"
    t.decimal "area_sqm", precision: 10, scale: 3, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.decimal "height", precision: 8, scale: 2
    t.integer "line_position", default: 1, null: false
    t.decimal "line_total", precision: 12, scale: 2, default: "0.0", null: false
    t.integer "product_id", null: false
    t.integer "quantity", default: 1, null: false
    t.integer "quote_request_id", null: false
    t.decimal "unit_price", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.decimal "width", precision: 8, scale: 2
    t.index ["product_id"], name: "index_quote_items_on_product_id"
    t.index ["quote_request_id"], name: "index_quote_items_on_quote_request_id"
  end

  create_table "quote_requests", force: :cascade do |t|
    t.datetime "approved_at"
    t.datetime "converted_to_job_at"
    t.datetime "created_at", null: false
    t.string "currency", default: "AUD", null: false
    t.string "customer_reference"
    t.decimal "height", precision: 8, scale: 2, null: false
    t.text "notes"
    t.datetime "priced_at"
    t.integer "quantity", default: 1, null: false
    t.string "quote_number", null: false
    t.integer "quote_template_id", null: false
    t.datetime "rejected_at"
    t.datetime "reviewed_at"
    t.datetime "sent_at"
    t.integer "status", default: 0, null: false
    t.decimal "subtotal", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "total", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.date "valid_until"
    t.decimal "width", precision: 8, scale: 2, null: false
    t.index ["quote_number"], name: "index_quote_requests_on_quote_number", unique: true
    t.index ["quote_template_id"], name: "index_quote_requests_on_quote_template_id"
    t.index ["user_id"], name: "index_quote_requests_on_user_id"
  end

  create_table "quote_templates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "default_template", default: false, null: false
    t.text "footer"
    t.string "heading", null: false
    t.text "intro"
    t.string "name", null: false
    t.text "terms"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_quote_templates_on_name", unique: true
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
  add_foreign_key "pricing_rules", "products"
  add_foreign_key "quote_items", "products"
  add_foreign_key "quote_items", "quote_requests"
  add_foreign_key "quote_requests", "quote_templates"
  add_foreign_key "quote_requests", "users"
end
