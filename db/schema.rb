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

ActiveRecord::Schema[8.0].define(version: 2026_10_27_000004) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "api_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_api_tokens_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.bigint "owner_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "shared", default: false, null: false
    t.text "scripts", default: "[]", null: false
    t.index ["name"], name: "index_projects_on_name_shared", unique: true, where: "(owner_id IS NULL)"
    t.index ["owner_id", "name"], name: "index_projects_on_owner_and_name", unique: true, where: "(owner_id IS NOT NULL)"
    t.index ["owner_id"], name: "index_projects_on_owner_id"
  end

  create_table "scripts", force: :cascade do |t|
    t.string "name", null: false
    t.text "content"
    t.string "language", null: false
    t.bigint "owner_id"
    t.string "visibility", default: "public", null: false
    t.integer "version", default: 1, null: false
    t.integer "priority", default: 3, null: false
    t.text "compiled"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["language", "name"], name: "index_scripts_on_language_and_name"
    t.index ["name"], name: "index_scripts_on_name"
    t.index ["owner_id", "name"], name: "index_scripts_on_owner_and_name", unique: true, where: "(owner_id IS NOT NULL)"
    t.index ["owner_id"], name: "index_scripts_on_owner_id"
    t.check_constraint "language::text = ANY (ARRAY['basic'::character varying, 'python'::character varying]::text[])", name: "scripts_language_known"
    t.check_constraint "priority >= 1 AND priority <= 5", name: "scripts_priority_range"
    t.check_constraint "version >= 1", name: "scripts_version_positive"
    t.check_constraint "visibility::text = ANY (ARRAY['public'::character varying, 'unlisted'::character varying, 'private'::character varying]::text[])", name: "scripts_visibility_known"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "password_digest"
    t.index "lower((email)::text)", name: "index_users_on_lower_email", unique: true
    t.index "lower((name)::text)", name: "index_users_on_lower_name", unique: true
  end

  create_table "viewport", force: :cascade do |t|
    t.string "name", null: false
    t.jsonb "content", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "owner_id"
    t.index ["name"], name: "index_viewport_on_name_shared", unique: true, where: "(owner_id IS NULL)"
    t.index ["owner_id", "name"], name: "index_viewport_on_owner_and_name", unique: true, where: "(owner_id IS NOT NULL)"
    t.index ["owner_id"], name: "index_viewport_on_owner_id"
  end

  add_foreign_key "api_tokens", "users", on_delete: :cascade
  add_foreign_key "projects", "users", column: "owner_id"
  add_foreign_key "scripts", "users", column: "owner_id"
  add_foreign_key "viewport", "users", column: "owner_id"
end
