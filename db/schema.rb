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

ActiveRecord::Schema[8.0].define(version: 2026_06_15_170053) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "coffee_profiles", force: :cascade do |t|
    t.bigint "scan_id", null: false
    t.string "product_name"
    t.text "ingredients"
    t.string "net_weight"
    t.integer "net_weight_g"
    t.string "origin_country"
    t.string "process"
    t.string "varietal"
    t.string "region"
    t.string "altitude"
    t.integer "altitude_min_m"
    t.integer "altitude_max_m"
    t.string "roast_level"
    t.string "flavor_notes", default: [], array: true
    t.string "manufacturer"
    t.string "manufacturer_address"
    t.string "phone"
    t.string "website"
    t.string "origin"
    t.text "storage"
    t.date "manufactured_on"
    t.date "expires_on"
    t.string "language"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["origin_country"], name: "index_coffee_profiles_on_origin_country"
    t.index ["roast_level"], name: "index_coffee_profiles_on_roast_level"
    t.index ["scan_id"], name: "index_coffee_profiles_on_scan_id", unique: true
  end

  create_table "scans", force: :cascade do |t|
    t.text "text"
    t.string "category"
    t.datetime "recognized_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_scans_on_category"
  end

  add_foreign_key "coffee_profiles", "scans"
end
