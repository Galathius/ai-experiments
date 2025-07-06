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

ActiveRecord::Schema[8.0].define(version: 2025_07_06_082517) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "vector"

  create_table "action_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "tool_name"
    t.jsonb "parameters"
    t.jsonb "result"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_action_logs_on_user_id"
  end

  create_table "calendar_events", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "google_event_id", null: false
    t.text "title"
    t.text "description"
    t.datetime "start_time", null: false
    t.datetime "end_time"
    t.string "location"
    t.text "attendees"
    t.string "creator_email"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["end_time"], name: "index_calendar_events_on_end_time"
    t.index ["google_event_id"], name: "index_calendar_events_on_google_event_id", unique: true
    t.index ["start_time"], name: "index_calendar_events_on_start_time"
    t.index ["status"], name: "index_calendar_events_on_status"
    t.index ["user_id"], name: "index_calendar_events_on_user_id"
  end

  create_table "chats", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "title"
    t.index ["user_id"], name: "index_chats_on_user_id"
  end

  create_table "emails", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "gmail_id", null: false
    t.text "subject"
    t.text "body"
    t.string "from_email"
    t.text "to_email"
    t.text "cc_email"
    t.text "bcc_email"
    t.datetime "received_at"
    t.string "thread_id"
    t.text "labels"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["from_email"], name: "index_emails_on_from_email"
    t.index ["gmail_id"], name: "index_emails_on_gmail_id", unique: true
    t.index ["received_at"], name: "index_emails_on_received_at"
    t.index ["thread_id"], name: "index_emails_on_thread_id"
    t.index ["user_id"], name: "index_emails_on_user_id"
  end

  create_table "embeddings", force: :cascade do |t|
    t.string "embeddable_type", null: false
    t.bigint "embeddable_id", null: false
    t.text "content", null: false
    t.vector "vector", limit: 1536, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["embeddable_type", "embeddable_id"], name: "index_embeddings_on_embeddable"
    t.index ["embeddable_type", "embeddable_id"], name: "index_embeddings_on_embeddable_type_and_embeddable_id", unique: true
    t.index ["vector"], name: "index_embeddings_on_vector", opclass: :vector_cosine_ops, using: :ivfflat
  end

  create_table "hubspot_contacts", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "hubspot_contact_id"
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "company"
    t.string "phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_hubspot_contacts_on_user_id"
  end

  create_table "hubspot_notes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "hubspot_note_id"
    t.string "hubspot_contact_id"
    t.text "content"
    t.datetime "created_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_hubspot_notes_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "chat_id", null: false
    t.text "content"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_messages_on_chat_id"
  end

  create_table "omni_auth_identities", force: :cascade do |t|
    t.string "uid"
    t.string "provider"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "access_token"
    t.text "refresh_token"
    t.datetime "expires_at"
    t.index ["user_id"], name: "index_omni_auth_identities_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.string "source"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name", default: "", null: false
    t.string "last_name", default: "", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "action_logs", "users"
  add_foreign_key "calendar_events", "users"
  add_foreign_key "chats", "users"
  add_foreign_key "emails", "users"
  add_foreign_key "hubspot_contacts", "users"
  add_foreign_key "hubspot_notes", "users"
  add_foreign_key "messages", "chats"
  add_foreign_key "omni_auth_identities", "users"
  add_foreign_key "sessions", "users"
end
