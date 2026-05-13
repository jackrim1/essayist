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

ActiveRecord::Schema[8.1].define(version: 2026_05_13_175533) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"

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

  create_table "essays", force: :cascade do |t|
    t.string "author"
    t.text "content"
    t.datetime "created_at", null: false
    t.decimal "last_read_position", precision: 10, scale: 8, default: "0.0"
    t.string "original_filename"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "view_mode", default: 0, null: false
    t.integer "word_count"
    t.index ["user_id", "updated_at"], name: "index_essays_on_user_id_and_updated_at"
    t.index ["user_id"], name: "index_essays_on_user_id"
  end

  create_table "highlight_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "highlight_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["highlight_id", "tag_id"], name: "index_highlight_tags_on_highlight_id_and_tag_id", unique: true
    t.index ["highlight_id"], name: "index_highlight_tags_on_highlight_id"
    t.index ["tag_id"], name: "index_highlight_tags_on_tag_id"
  end

  create_table "highlights", force: :cascade do |t|
    t.jsonb "anchor", default: {}, null: false
    t.string "color", default: "yellow", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.bigint "essay_id", null: false
    t.text "note"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["anchor"], name: "index_highlights_on_anchor", using: :gin
    t.index ["essay_id", "created_at"], name: "index_highlights_on_essay_id_and_created_at"
    t.index ["essay_id"], name: "index_highlights_on_essay_id"
    t.index ["user_id"], name: "index_highlights_on_user_id"
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "name"], name: "index_tags_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_tags_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.jsonb "preferences", default: {}, null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["preferences"], name: "index_users_on_preferences", using: :gin
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "essays", "users"
  add_foreign_key "highlight_tags", "highlights"
  add_foreign_key "highlight_tags", "tags"
  add_foreign_key "highlights", "essays"
  add_foreign_key "highlights", "users"
  add_foreign_key "tags", "users"
end
