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

ActiveRecord::Schema[8.0].define(version: 2026_08_29_011000) do
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
    t.index ["landlord_id"], name: "index_houses_on_landlord_id"
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
  add_foreign_key "beds", "rooms"
  add_foreign_key "contracts", "houses", on_delete: :cascade
  add_foreign_key "contracts", "landlords", on_delete: :cascade
  add_foreign_key "contracts", "tenants", on_delete: :cascade
  add_foreign_key "floors", "houses"
  add_foreign_key "houses", "landlords"
  add_foreign_key "landlords", "users", column: "id", on_delete: :cascade
  add_foreign_key "maintenance_logs", "assets", on_delete: :cascade
  add_foreign_key "requests", "houses", on_delete: :cascade
  add_foreign_key "requests", "tenants", on_delete: :cascade
  add_foreign_key "requests", "users", column: "resolved_by_id"
  add_foreign_key "room_services", "rooms", on_delete: :cascade
  add_foreign_key "room_services", "service_variants", on_delete: :cascade
  add_foreign_key "rooms", "floors"
  add_foreign_key "service_variants", "services", on_delete: :cascade
  add_foreign_key "services", "houses", on_delete: :cascade
  add_foreign_key "tenant_stays", "rental_units"
  add_foreign_key "tenant_stays", "tenants"
  add_foreign_key "tenants", "users", column: "id", on_delete: :cascade
  add_foreign_key "vehicles", "houses", on_delete: :cascade
  add_foreign_key "vehicles", "tenants", on_delete: :cascade
end
