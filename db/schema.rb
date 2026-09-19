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

ActiveRecord::Schema[8.1].define(version: 2026_09_19_203909) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "unaccent"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "admins", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "fullname", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "last_login_at"
    t.string "password_digest", null: false
    t.string "role", default: "super_admin", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_admins_on_email", unique: true
  end

  create_table "assets", force: :cascade do |t|
    t.string "brand"
    t.string "category", null: false
    t.datetime "created_at", null: false
    t.string "model"
    t.string "note"
    t.integer "price", null: false
    t.date "purchased_at"
    t.bigint "room_id", null: false
    t.string "status", default: "normal", null: false
    t.datetime "updated_at", null: false
    t.index ["room_id"], name: "index_assets_on_room_id"
  end

  create_table "bank_accounts", force: :cascade do |t|
    t.string "account_holder", null: false
    t.string "account_number", null: false
    t.bigint "bank_id", null: false
    t.datetime "created_at", null: false
    t.boolean "is_default", default: false, null: false
    t.bigint "landlord_id", null: false
    t.string "payos_api_key"
    t.string "payos_checksum_key"
    t.string "payos_client_id"
    t.boolean "payos_enabled", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["bank_id"], name: "index_bank_accounts_on_bank_id"
    t.index ["landlord_id", "account_number", "bank_id"], name: "idx_unique_landlord_bank_acc", unique: true
    t.index ["landlord_id"], name: "index_bank_accounts_on_landlord_id"
  end

  create_table "banks", force: :cascade do |t|
    t.string "bin", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "logo_url"
    t.string "name", null: false
    t.string "short_name", null: false
    t.datetime "updated_at", null: false
    t.index ["bin"], name: "index_banks_on_bin", unique: true
    t.index ["code"], name: "index_banks_on_code", unique: true
  end

  create_table "beds", force: :cascade do |t|
    t.boolean "deleted", default: false, null: false
    t.boolean "is_available", default: true, null: false
    t.string "name", null: false
    t.bigint "room_id", null: false
    t.index ["room_id"], name: "index_beds_on_room_id"
  end

  create_table "contracts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "deposit_paid", default: false, null: false
    t.date "due_date", null: false
    t.date "end_date"
    t.bigint "house_id", null: false
    t.string "landlord_citizen_id", null: false
    t.bigint "landlord_id", null: false
    t.string "name", null: false
    t.string "note"
    t.date "start_date", null: false
    t.date "temp_resid_due_date"
    t.boolean "temp_resid_registered", default: false
    t.string "tenant_citizen_id", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["end_date", "due_date"], name: "index_contracts_on_end_date_and_due_date"
    t.index ["house_id"], name: "index_contracts_on_house_id"
    t.index ["landlord_id"], name: "index_contracts_on_landlord_id"
    t.index ["tenant_id"], name: "index_contracts_on_tenant_id"
    t.check_constraint "due_date > start_date", name: "contracts_due_date_after_start_date"
  end

  create_table "floors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "house_id", null: false
    t.string "name", null: false
    t.integer "position", null: false
    t.integer "rooms_count", default: 0
    t.datetime "updated_at", null: false
    t.index ["house_id", "name"], name: "index_floors_on_house_id_and_name", unique: true
    t.index ["house_id", "position"], name: "index_floors_on_house_id_and_position", unique: true
    t.index ["house_id"], name: "index_floors_on_house_id"
  end

  create_table "houses", force: :cascade do |t|
    t.string "address_l1", null: false
    t.string "address_l2", null: false
    t.string "address_l3", null: false
    t.datetime "created_at", null: false
    t.integer "floors_count", default: 0, null: false
    t.integer "inv_creation_date", default: 0, null: false
    t.boolean "is_deleted", default: false, null: false
    t.bigint "landlord_id", null: false
    t.string "mode", null: false
    t.string "name", null: false
    t.string "transfer_note_template"
    t.datetime "updated_at", null: false
    t.index ["landlord_id"], name: "index_houses_on_landlord_id"
  end

  create_table "invoice_items", force: :cascade do |t|
    t.bigint "amount", null: false
    t.datetime "created_at", null: false
    t.date "end_date"
    t.bigint "invoice_id", null: false
    t.string "item_type", null: false
    t.integer "latest_reading"
    t.string "name", null: false
    t.string "note"
    t.integer "prev_reading"
    t.decimal "quantity", precision: 10, scale: 2, default: "1.0", null: false
    t.bigint "service_variant_id"
    t.date "start_date"
    t.string "unit"
    t.bigint "unit_price", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_invoice_items_on_invoice_id"
    t.index ["service_variant_id"], name: "index_invoice_items_on_service_variant_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.bigint "bank_account_id"
    t.date "billing_month", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.datetime "discarded_at"
    t.date "due_date", null: false
    t.date "end_date"
    t.bigint "house_id", null: false
    t.string "invoice_type", default: "room", null: false
    t.text "note"
    t.datetime "paid_at"
    t.bigint "paid_by_id"
    t.string "paid_by_role"
    t.string "payment_method"
    t.bigint "room_id", null: false
    t.date "start_date"
    t.string "status", default: "pending", null: false
    t.bigint "subtotal", default: 0, null: false
    t.bigint "tenant_id"
    t.string "title", default: "Thu tiền hàng tháng"
    t.bigint "total_addition", default: 0, null: false
    t.bigint "total_amount", default: 0, null: false
    t.bigint "total_discount", default: 0, null: false
    t.string "transfer_note"
    t.text "undo_reason"
    t.datetime "undone_at"
    t.bigint "undone_by_id"
    t.datetime "updated_at", null: false
    t.index ["bank_account_id"], name: "index_invoices_on_bank_account_id"
    t.index ["code"], name: "index_invoices_on_code", unique: true
    t.index ["created_by_id"], name: "index_invoices_on_created_by_id"
    t.index ["house_id", "billing_month"], name: "index_invoices_on_house_id_and_billing_month"
    t.index ["house_id"], name: "index_invoices_on_house_id"
    t.index ["paid_by_id"], name: "index_invoices_on_paid_by_id"
    t.index ["room_id", "billing_month", "invoice_type"], name: "idx_invoices_room_month_type"
    t.index ["room_id"], name: "index_invoices_on_room_id"
    t.index ["status", "due_date"], name: "index_invoices_on_status_and_due_date"
    t.index ["status"], name: "index_invoices_on_status"
    t.index ["tenant_id"], name: "index_invoices_on_tenant_id"
    t.index ["undone_by_id"], name: "index_invoices_on_undone_by_id"
  end

  create_table "issue_reports", force: :cascade do |t|
    t.text "admin_notes"
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.string "email", null: false
    t.datetime "resolved_at"
    t.bigint "resolved_by_id"
    t.string "status", default: "pending", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_issue_reports_on_created_at"
    t.index ["email"], name: "index_issue_reports_on_email"
    t.index ["resolved_by_id"], name: "index_issue_reports_on_resolved_by_id"
    t.index ["status"], name: "index_issue_reports_on_status"
  end

  create_table "landlords", force: :cascade do |t|
    t.integer "deleted_houses_count", default: 0, null: false
    t.integer "houses_count", default: 0, null: false
    t.integer "posts_count", default: 0, null: false
  end

  create_table "leave_house_requests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "maintenance_logs", force: :cascade do |t|
    t.bigint "asset_id", null: false
    t.string "content", null: false
    t.bigint "cost", default: 0, null: false
    t.datetime "created_at", null: false
    t.date "performed_on", null: false
    t.datetime "updated_at", null: false
    t.index ["asset_id"], name: "index_maintenance_logs_on_asset_id"
  end

  create_table "noticed_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "notifications_count"
    t.jsonb "params"
    t.bigint "record_id"
    t.string "record_type"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id"], name: "index_noticed_events_on_record"
  end

  create_table "noticed_notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "read_at", precision: nil
    t.bigint "recipient_id", null: false
    t.string "recipient_type", null: false
    t.datetime "seen_at", precision: nil
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_noticed_notifications_on_event_id"
    t.index ["recipient_type", "recipient_id"], name: "index_noticed_notifications_on_recipient"
  end

  create_table "payment_orders", force: :cascade do |t|
    t.string "checkout_url"
    t.datetime "created_at", null: false
    t.bigint "invoice_id", null: false
    t.jsonb "metadata", default: {}
    t.bigint "order_code", null: false
    t.string "payment_link_id"
    t.string "provider", default: "payos", null: false
    t.text "qr_code"
    t.string "status", default: "PENDING"
    t.datetime "updated_at", null: false
    t.index ["invoice_id", "provider"], name: "index_payment_orders_on_invoice_id_and_provider"
    t.index ["invoice_id"], name: "index_payment_orders_on_invoice_id"
    t.index ["order_code"], name: "index_payment_orders_on_order_code", unique: true
  end

  create_table "rental_units", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "deposit", null: false
    t.integer "rent", null: false
    t.bigint "rentable_id", null: false
    t.string "rentable_type", null: false
    t.datetime "updated_at", null: false
    t.index ["rentable_type", "rentable_id"], name: "index_rental_units_on_rentable"
  end

  create_table "repair_requests", force: :cascade do |t|
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
  end

  create_table "requests", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "house_id", null: false
    t.string "rejection_reason"
    t.bigint "requestable_id", null: false
    t.string "requestable_type", null: false
    t.datetime "resolved_at"
    t.bigint "resolved_by_id"
    t.string "status", default: "pending", null: false
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["house_id"], name: "index_requests_on_house_id"
    t.index ["requestable_type", "requestable_id"], name: "index_requests_on_requestable_type_and_requestable_id", unique: true
    t.index ["resolved_by_id"], name: "index_requests_on_resolved_by_id"
    t.index ["tenant_id"], name: "index_requests_on_tenant_id"
  end

  create_table "room_services", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "room_id", null: false
    t.bigint "service_variant_id", null: false
    t.datetime "updated_at", null: false
    t.index ["room_id", "service_variant_id"], name: "idx_room_service_variant", unique: true
    t.index ["room_id"], name: "index_room_services_on_room_id"
    t.index ["service_variant_id"], name: "index_room_services_on_service_variant_id"
  end

  create_table "rooms", force: :cascade do |t|
    t.float "area", null: false
    t.datetime "created_at", null: false
    t.boolean "deleted", default: false, null: false
    t.bigint "floor_id", null: false
    t.integer "max_slots", default: 1
    t.string "name", null: false
    t.integer "tenants_count", default: 0
    t.datetime "updated_at", null: false
    t.index ["floor_id", "name"], name: "index_rooms_on_floor_id_and_name", unique: true
    t.index ["floor_id"], name: "index_rooms_on_floor_id"
  end

  create_table "service_usage_logs", force: :cascade do |t|
    t.date "billing_month", null: false
    t.datetime "confirmed_at"
    t.bigint "confirmed_by_id"
    t.datetime "created_at", null: false
    t.date "end_date", null: false
    t.bigint "invoice_id"
    t.boolean "is_confirmed", default: false, null: false
    t.integer "latest_reading"
    t.integer "prev_reading", default: 0, null: false
    t.bigint "room_id", null: false
    t.bigint "service_id"
    t.string "service_name", null: false
    t.bigint "service_variant_id"
    t.date "start_date", null: false
    t.bigint "submitted_by_id"
    t.string "submitted_by_type"
    t.string "unit", null: false
    t.integer "unit_price", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "usage_quantity"
    t.index ["confirmed_by_id"], name: "index_service_usage_logs_on_confirmed_by_id"
    t.index ["invoice_id"], name: "index_service_usage_logs_on_invoice_id"
    t.index ["room_id", "service_id", "billing_month"], name: "idx_usage_logs_room_service_month", unique: true
    t.index ["room_id"], name: "index_service_usage_logs_on_room_id"
    t.index ["service_id"], name: "index_service_usage_logs_on_service_id"
    t.index ["service_variant_id"], name: "index_service_usage_logs_on_service_variant_id"
    t.index ["submitted_by_type", "submitted_by_id"], name: "index_service_usage_logs_on_submitted_by"
  end

  create_table "service_variants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "fee", default: 0, null: false
    t.boolean "is_real_time", default: false, null: false
    t.bigint "service_id", null: false
    t.string "unit", null: false
    t.datetime "updated_at", null: false
    t.index ["service_id"], name: "index_service_variants_on_service_id"
  end

  create_table "services", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "house_id", null: false
    t.string "name", null: false
    t.string "note"
    t.datetime "updated_at", null: false
    t.index ["house_id"], name: "index_services_on_house_id"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "tenant_stays", force: :cascade do |t|
    t.datetime "checkin_at", null: false
    t.datetime "checkout_at"
    t.boolean "has_contract", default: false, null: false
    t.bigint "rental_unit_id", null: false
    t.bigint "tenant_id", null: false
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
    t.string "address", null: false
    t.date "bday", null: false
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.string "fullname", null: false
    t.boolean "is_active", default: true, null: false
    t.string "otp_code"
    t.datetime "otp_sent_at"
    t.string "password_digest", null: false
    t.string "role"
    t.string "sex", limit: 1, null: false
    t.string "tel", null: false
    t.datetime "tel_verified_at"
    t.datetime "updated_at", null: false
    t.index ["tel", "role"], name: "index_users_on_tel_and_role", unique: true, where: "(discarded_at IS NULL)"
  end

  create_table "vehicle_requests", force: :cascade do |t|
    t.string "brand"
    t.string "color"
    t.datetime "consent_given_at", null: false
    t.datetime "created_at", null: false
    t.datetime "documents_purged_at"
    t.string "license_plate", null: false
    t.string "model"
    t.datetime "updated_at", null: false
    t.string "vehicle_type", default: "motorbike", null: false
    t.index ["license_plate"], name: "index_vehicle_requests_on_license_plate"
  end

  create_table "vehicles", force: :cascade do |t|
    t.string "brand"
    t.datetime "created_at", null: false
    t.bigint "house_id", null: false
    t.string "license_plate", null: false
    t.string "model"
    t.bigint "tenant_id", null: false
    t.datetime "updated_at", null: false
    t.string "vehicle_type", default: "motorbike", null: false
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
  add_foreign_key "issue_reports", "admins", column: "resolved_by_id"
  add_foreign_key "landlords", "users", column: "id", on_delete: :cascade
  add_foreign_key "maintenance_logs", "assets", on_delete: :cascade
  add_foreign_key "payment_orders", "invoices", on_delete: :cascade
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
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "tenant_stays", "rental_units"
  add_foreign_key "tenant_stays", "tenants"
  add_foreign_key "tenants", "users", column: "id", on_delete: :cascade
  add_foreign_key "vehicles", "houses", on_delete: :cascade
  add_foreign_key "vehicles", "tenants", on_delete: :cascade
end
