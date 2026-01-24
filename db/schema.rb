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

ActiveRecord::Schema[8.0].define(version: 2026_01_24_072051) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "floors", force: :cascade do |t|
    t.bigint "house_id", null: false
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["house_id", "name"], name: "index_floors_on_house_id_and_name", unique: true
    t.index ["house_id"], name: "index_floors_on_house_id"
  end

  create_table "houses", force: :cascade do |t|
    t.string "name", null: false
    t.string "address_l1", null: false
    t.string "address_l2", null: false
    t.string "address_l3", null: false
    t.integer "floors_count", default: 1, null: false
    t.integer "rooms_count", default: 1, null: false
    t.integer "inv_creation_date", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.bigint "landlord_id", null: false
    t.string "mode"
    t.index ["landlord_id"], name: "index_houses_on_landlord_id"
  end

  create_table "landlords", force: :cascade do |t|
    t.integer "posts_count", default: 0, null: false
    t.integer "houses_count", default: 0, null: false
  end

  create_table "room_services", primary_key: ["service_id", "room_id"], force: :cascade do |t|
    t.integer "fee", null: false
    t.boolean "is_real_time", default: false, null: false
    t.bigint "service_id", null: false
    t.bigint "room_id", null: false
    t.bigint "service_unit_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["room_id"], name: "index_room_services_on_room_id"
    t.index ["service_id"], name: "index_room_services_on_service_id"
    t.index ["service_unit_id"], name: "index_room_services_on_service_unit_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.bigint "floor_id", null: false
    t.string "name", null: false
    t.integer "tenants_count", default: 0
    t.integer "max_slots", default: 1
    t.float "area", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "rent", null: false
    t.index ["floor_id", "name"], name: "index_rooms_on_floor_id_and_name", unique: true
    t.index ["floor_id"], name: "index_rooms_on_floor_id"
  end

  create_table "service_unit_translations", force: :cascade do |t|
    t.bigint "service_unit_id", null: false
    t.string "locale", null: false
    t.string "name", null: false
    t.index ["service_unit_id", "locale"], name: "index_service_unit_translations_on_service_unit_id_and_locale", unique: true
    t.index ["service_unit_id"], name: "index_service_unit_translations_on_service_unit_id"
  end

  create_table "service_units", force: :cascade do |t|
    t.string "code", null: false
    t.index ["code"], name: "index_service_units_on_code", unique: true
  end

  create_table "services", force: :cascade do |t|
    t.string "name", null: false
    t.string "note"
    t.bigint "house_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["house_id"], name: "index_services_on_house_id"
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "floors", "houses"
  add_foreign_key "houses", "landlords"
  add_foreign_key "landlords", "users", column: "id", on_delete: :cascade
  add_foreign_key "room_services", "rooms", on_delete: :cascade
  add_foreign_key "room_services", "service_units", on_delete: :cascade
  add_foreign_key "room_services", "services", on_delete: :cascade
  add_foreign_key "rooms", "floors"
  add_foreign_key "service_unit_translations", "service_units", on_delete: :cascade
  add_foreign_key "services", "houses", on_delete: :cascade
  add_foreign_key "tenants", "users", column: "id", on_delete: :cascade
end
