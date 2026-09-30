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

ActiveRecord::Schema[8.0].define(version: 2026_09_30_000001) do
  create_schema "_heroku"

  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_stat_statements"

  create_table "basic_source", force: :cascade do |t|
    t.string "name"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "priority", default: 3, null: false
    t.text "compiled"
    t.index ["name"], name: "index_basic_source_on_name"
    t.check_constraint "priority >= 1 AND priority <= 5", name: "basic_source_priority_range"
  end

  create_table "cobol_models", force: :cascade do |t|
    t.text "file_name", null: false
    t.text "content", default: "", null: false
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.timestamptz "updated_at", default: -> { "now()" }, null: false

    t.unique_constraint ["file_name"], name: "cobol_models_file_name_key"
  end

  create_table "cobol_source_files", id: :serial, force: :cascade do |t|
    t.string "file_name", limit: 512, null: false
    t.text "content", null: false
    t.timestamptz "created_at", default: -> { "CURRENT_TIMESTAMP" }
    t.timestamptz "updated_at", default: -> { "CURRENT_TIMESTAMP" }

    t.unique_constraint ["file_name"], name: "cobol_source_files_file_name_key"
  end

  create_table "data_models", force: :cascade do |t|
    t.text "file_name", null: false
    t.text "content", default: "", null: false
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.timestamptz "updated_at", default: -> { "now()" }, null: false

    t.unique_constraint ["file_name"], name: "data_models_file_name_key"
  end

  create_table "jcl_models", force: :cascade do |t|
    t.text "file_name", null: false
    t.text "content", default: "", null: false
    t.timestamptz "created_at", default: -> { "now()" }, null: false
    t.timestamptz "updated_at", default: -> { "now()" }, null: false

    t.unique_constraint ["file_name"], name: "jcl_models_file_name_key"
  end

  create_table "python_source", force: :cascade do |t|
    t.string "name"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "priority", default: 3, null: false
    t.text "compiled"
    t.index ["name"], name: "index_python_source_on_name"
    t.check_constraint "priority >= 1 AND priority <= 5", name: "python_source_priority_range"
  end

  create_table "python_source_files", id: :serial, force: :cascade do |t|
    t.string "file_name", limit: 512, null: false
    t.text "content", null: false
    t.timestamptz "created_at", default: -> { "CURRENT_TIMESTAMP" }
    t.timestamptz "updated_at", default: -> { "CURRENT_TIMESTAMP" }

    t.unique_constraint ["file_name"], name: "python_source_files_file_name_key"
  end

  create_table "viewport", force: :cascade do |t|
    t.string "name", null: false
    t.jsonb "content", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_viewport_on_name", unique: true
  end
end
