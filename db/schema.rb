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

ActiveRecord::Schema[8.0].define(version: 2026_09_02_041001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "unaccent"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admins", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "fullname", null: false
    t.string "role", default: "super_admin", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "last_login_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
  end

  create_table "assets", force: :cascade do |t|
    t.bigint "room_id", null: false
    t.integer "price", null: false
    t.date "purchased_at"
    t.string "brand"
    t.string "model"
    t.string "category", null: false
    t.string "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "normal", null: false
    t.index ["room_id"], name: "index_assets_on_room_id"
  end

  create_table "bank_accounts", force: :cascade do |t|
    t.bigint "landlord_id", null: false
    t.bigint "bank_id", null: false
    t.string "account_number", null: false
    t.string "account_holder", null: false
    t.boolean "is_default", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bank_id"], name: "index_bank_accounts_on_bank_id"
    t.index ["landlord_id", "account_number", "bank_id"], name: "idx_unique_landlord_bank_acc", unique: true
    t.index ["landlord_id"], name: "index_bank_accounts_on_landlord_id"
  end

  create_table "banks", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.string "bin", null: false
    t.string "short_name", null: false
    t.string "logo_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bin"], name: "index_banks_on_bin", unique: true
    t.index ["code"], name: "index_banks_on_code", unique: true
  end

  create_table "beds", force: :cascade do |t|
    t.bigint "room_id", null: false
    t.string "name", null: false
    t.boolean "is_available", default: true, null: false
    t.boolean "deleted", default: false, null: false
    t.index ["room_id"], name: "index_beds_on_room_id"
  end

  create_table "contracts", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "landlord_id", null: false
    t.bigint "house_id", null: false
    t.string "tenant_citizen_id", null: false
    t.boolean "temp_resid_registered", default: false
    t.date "temp_resid_due_date"
    t.date "start_date", null: false
    t.date "due_date", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "end_date"
    t.string "name", null: false
    t.boolean "deposit_paid", default: false, null: false
    t.string "note"
    t.string "landlord_citizen_id", null: false
    t.index ["house_id"], name: "index_contracts_on_house_id"
    t.index ["landlord_id"], name: "index_contracts_on_landlord_id"
    t.index ["tenant_id"], name: "index_contracts_on_tenant_id"
    t.check_constraint "due_date > start_date", name: "contracts_due_date_after_start_date"
  end

  create_table "floors", force: :cascade do |t|
    t.bigint "house_id", null: false
    t.string "name", null: false
    t.integer "rooms_count", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "position", null: false
    t.index ["house_id", "name"], name: "index_floors_on_house_id_and_name", unique: true
    t.index ["house_id", "position"], name: "index_floors_on_house_id_and_position", unique: true
    t.index ["house_id"], name: "index_floors_on_house_id"
  end

  create_table "houses", force: :cascade do |t|
    t.string "name", null: false
    t.string "address_l1", null: false
    t.string "address_l2", null: false
    t.string "address_l3", null: false
    t.string "mode", null: false
    t.integer "floors_count", default: 0, null: false
    t.integer "inv_creation_date", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_deleted", default: false, null: false
    t.bigint "landlord_id", null: false
    t.string "transfer_note_template"
    t.index ["landlord_id"], name: "index_houses_on_landlord_id"
  end

  create_table "invoice_items", force: :cascade do |t|
    t.bigint "invoice_id", null: false
    t.bigint "service_variant_id"
    t.string "item_type", null: false
    t.string "name", null: false
    t.string "unit"
    t.bigint "unit_price", default: 0, null: false
    t.decimal "quantity", precision: 10, scale: 2, default: "1.0", null: false
    t.bigint "amount", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "start_date"
    t.date "end_date"
    t.integer "prev_reading"
    t.integer "latest_reading"
    t.string "note"
    t.index ["invoice_id"], name: "index_invoice_items_on_invoice_id"
    t.index ["service_variant_id"], name: "index_invoice_items_on_service_variant_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.string "code", null: false
    t.bigint "house_id", null: false
    t.bigint "room_id", null: false
    t.bigint "tenant_id"
    t.bigint "bank_account_id"
    t.bigint "created_by_id", null: false
    t.string "invoice_type", default: "room", null: false
    t.date "billing_month", null: false
    t.date "due_date", null: false
    t.bigint "subtotal", default: 0, null: false
    t.bigint "total_discount", default: 0, null: false
    t.bigint "total_addition", default: 0, null: false
    t.bigint "total_amount", default: 0, null: false
    t.string "status", default: "pending", null: false
    t.datetime "paid_at"
    t.string "payment_method"
    t.string "transfer_note"
    t.text "note"
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "start_date"
    t.date "end_date"
    t.string "title", default: "Thu tiền hàng tháng"
    t.index ["bank_account_id"], name: "index_invoices_on_bank_account_id"
    t.index ["code"], name: "index_invoices_on_code", unique: true
    t.index ["created_by_id"], name: "index_invoices_on_created_by_id"
    t.index ["house_id", "billing_month"], name: "index_invoices_on_house_id_and_billing_month"
    t.index ["house_id"], name: "index_invoices_on_house_id"
    t.index ["room_id", "billing_month", "invoice_type"], name: "idx_invoices_room_month_type"
    t.index ["room_id"], name: "index_invoices_on_room_id"
    t.index ["status"], name: "index_invoices_on_status"
    t.index ["tenant_id"], name: "index_invoices_on_tenant_id"
  end

  create_table "landlords", force: :cascade do |t|
    t.integer "posts_count", default: 0, null: false
    t.integer "houses_count", default: 0, null: false
  end

  create_table "leave_house_requests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "maintenance_logs", force: :cascade do |t|
    t.bigint "asset_id", null: false
    t.bigint "cost", default: 0, null: false
    t.string "content", null: false
    t.date "performed_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id"], name: "index_maintenance_logs_on_asset_id"
  end

  create_table "noticed_events", force: :cascade do |t|
    t.string "type"
    t.string "record_type"
    t.bigint "record_id"
    t.jsonb "params"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "notifications_count"
    t.index ["record_type", "record_id"], name: "index_noticed_events_on_record"
  end

  create_table "noticed_notifications", force: :cascade do |t|
    t.string "type"
    t.bigint "event_id", null: false
    t.string "recipient_type", null: false
    t.bigint "recipient_id", null: false
    t.datetime "read_at", precision: nil
    t.datetime "seen_at", precision: nil
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_noticed_notifications_on_event_id"
    t.index ["recipient_type", "recipient_id"], name: "index_noticed_notifications_on_recipient"
  end

  create_table "rental_units", force: :cascade do |t|
    t.string "rentable_type", null: false
    t.bigint "rentable_id", null: false
    t.integer "rent", null: false
    t.integer "deposit", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["rentable_type", "rentable_id"], name: "index_rental_units_on_rentable"
  end

  create_table "repair_requests", force: :cascade do |t|
    t.string "title", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "requests", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "house_id", null: false
    t.string "requestable_type", null: false
    t.bigint "requestable_id", null: false
    t.string "status", default: "pending", null: false
    t.string "rejection_reason"
    t.bigint "resolved_by_id"
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["house_id"], name: "index_requests_on_house_id"
    t.index ["requestable_type", "requestable_id"], name: "index_requests_on_requestable_type_and_requestable_id", unique: true
    t.index ["resolved_by_id"], name: "index_requests_on_resolved_by_id"
    t.index ["tenant_id"], name: "index_requests_on_tenant_id"
  end

  create_table "room_services", force: :cascade do |t|
    t.bigint "room_id", null: false
    t.bigint "service_variant_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["room_id", "service_variant_id"], name: "idx_room_service_variant", unique: true
    t.index ["room_id"], name: "index_room_services_on_room_id"
    t.index ["service_variant_id"], name: "index_room_services_on_service_variant_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.bigint "floor_id", null: false
    t.string "name", null: false
    t.integer "tenants_count", default: 0
    t.integer "max_slots", default: 1
    t.float "area", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "deleted", default: false, null: false
    t.index ["floor_id", "name"], name: "index_rooms_on_floor_id_and_name", unique: true
    t.index ["floor_id"], name: "index_rooms_on_floor_id"
  end

  create_table "service_usage_logs", force: :cascade do |t|
    t.bigint "room_id", null: false
    t.bigint "service_id"
    t.bigint "service_variant_id"
    t.bigint "invoice_id"
    t.string "service_name", null: false
    t.string "unit", null: false
    t.integer "unit_price", default: 0, null: false
    t.date "billing_month", null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.integer "prev_reading", default: 0, null: false
    t.integer "latest_reading"
    t.integer "usage_quantity"
    t.boolean "is_confirmed", default: false, null: false
    t.datetime "confirmed_at"
    t.string "submitted_by_type"
    t.bigint "submitted_by_id"
    t.bigint "confirmed_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmed_by_id"], name: "index_service_usage_logs_on_confirmed_by_id"
    t.index ["invoice_id"], name: "index_service_usage_logs_on_invoice_id"
    t.index ["room_id", "service_id", "billing_month"], name: "idx_usage_logs_room_service_month", unique: true
    t.index ["room_id"], name: "index_service_usage_logs_on_room_id"
    t.index ["service_id"], name: "index_service_usage_logs_on_service_id"
    t.index ["service_variant_id"], name: "index_service_usage_logs_on_service_variant_id"
    t.index ["submitted_by_type", "submitted_by_id"], name: "index_service_usage_logs_on_submitted_by"
  end

  create_table "service_variants", force: :cascade do |t|
    t.integer "fee", default: 0, null: false
    t.string "unit", null: false
    t.boolean "is_real_time", default: false, null: false
    t.bigint "service_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_id"], name: "index_service_variants_on_service_id"
  end

  create_table "services", force: :cascade do |t|
    t.string "name", null: false
    t.string "note"
    t.bigint "house_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["house_id"], name: "index_services_on_house_id"
  end

  create_table "tenant_stays", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "rental_unit_id", null: false
    t.datetime "checkin_at", null: false
    t.datetime "checkout_at"
    t.boolean "has_contract", default: false, null: false
    t.index ["rental_unit_id", "checkin_at"], name: "index_tenant_stays_on_rental_unit_id_and_checkin_at"
    t.index ["rental_unit_id"], name: "index_tenant_stays_on_active_rental_unit", unique: true, where: "(checkout_at IS NULL)"
    t.index ["rental_unit_id"], name: "index_tenant_stays_on_rental_unit_id"
    t.index ["tenant_id", "checkin_at"], name: "index_tenant_stays_on_tenant_id_and_checkin_at"
    t.index ["tenant_id"], name: "index_tenant_stays_on_active_tenant", unique: true, where: "(checkout_at IS NULL)"
    t.index ["tenant_id"], name: "index_tenant_stays_on_tenant_id"
    t.check_constraint "checkout_at IS NULL OR checkout_at >= checkin_at", name: "tenant_stays_valid_dates"
  end

  create_table "tenants", force: :cascade do |t|
    t.integer "saved_posts_count", default: 0, null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "fullname", null: false
    t.string "tel", null: false
    t.string "password_digest", null: false
    t.string "sex", limit: 1, null: false
    t.date "bday", null: false
    t.string "address", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_active", default: true, null: false
    t.string "otp_code"
    t.datetime "otp_sent_at"
    t.datetime "tel_verified_at"
    t.string "role"
    t.datetime "discarded_at"
    t.index ["tel", "role"], name: "index_users_on_tel_and_role", unique: true, where: "(discarded_at IS NULL)"
  end

  create_table "vehicle_requests", force: :cascade do |t|
    t.string "license_plate", null: false
    t.string "vehicle_type", default: "motorbike", null: false
    t.string "brand"
    t.string "model"
    t.string "color"
    t.datetime "consent_given_at", null: false
    t.datetime "documents_purged_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["license_plate"], name: "index_vehicle_requests_on_license_plate"
  end

  create_table "vehicles", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "house_id", null: false
    t.string "license_plate", null: false
    t.string "vehicle_type", default: "motorbike", null: false
    t.string "brand"
    t.string "model"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["house_id"], name: "index_vehicles_on_house_id"
    t.index ["license_plate", "house_id"], name: "index_vehicles_on_license_plate_and_house_id", unique: true
    t.index ["tenant_id"], name: "index_vehicles_on_tenant_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "assets", "rooms", on_delete: :cascade
  add_foreign_key "bank_accounts", "banks"
  add_foreign_key "bank_accounts", "landlords", on_delete: :cascade
  add_foreign_key "beds", "rooms"
  add_foreign_key "contracts", "houses", on_delete: :cascade
  add_foreign_key "contracts", "landlords", on_delete: :cascade
  add_foreign_key "contracts", "tenants", on_delete: :cascade
  add_foreign_key "floors", "houses"
  add_foreign_key "houses", "landlords"
  add_foreign_key "invoice_items", "invoices", on_delete: :cascade
  add_foreign_key "invoice_items", "service_variants", on_delete: :nullify
  add_foreign_key "invoices", "bank_accounts", on_delete: :nullify
  add_foreign_key "invoices", "houses", on_delete: :cascade
  add_foreign_key "invoices", "rooms", on_delete: :cascade
  add_foreign_key "invoices", "tenants", on_delete: :nullify
  add_foreign_key "invoices", "users", column: "created_by_id"
  add_foreign_key "landlords", "users", column: "id", on_delete: :cascade
  add_foreign_key "maintenance_logs", "assets", on_delete: :cascade
  add_foreign_key "requests", "houses", on_delete: :cascade
  add_foreign_key "requests", "tenants", on_delete: :cascade
  add_foreign_key "requests", "users", column: "resolved_by_id"
  add_foreign_key "room_services", "rooms", on_delete: :cascade
  add_foreign_key "room_services", "service_variants", on_delete: :cascade
  add_foreign_key "rooms", "floors"
  add_foreign_key "service_usage_logs", "invoices", on_delete: :nullify
  add_foreign_key "service_usage_logs", "rooms", on_delete: :cascade
  add_foreign_key "service_usage_logs", "service_variants", on_delete: :nullify
  add_foreign_key "service_usage_logs", "services", on_delete: :nullify
  add_foreign_key "service_usage_logs", "users", column: "confirmed_by_id"
  add_foreign_key "service_variants", "services", on_delete: :cascade
  add_foreign_key "services", "houses", on_delete: :cascade
  add_foreign_key "tenant_stays", "rental_units"
  add_foreign_key "tenant_stays", "tenants"
  add_foreign_key "tenants", "users", column: "id", on_delete: :cascade
  add_foreign_key "vehicles", "houses", on_delete: :cascade
  add_foreign_key "vehicles", "tenants", on_delete: :cascade
end
