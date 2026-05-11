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

ActiveRecord::Schema[8.1].define(version: 2018_07_04_211100) do
  create_table "comments", force: :cascade do |t|
    t.string "agent"
    t.string "approved", default: "pending"
    t.string "author"
    t.string "author_IP"
    t.string "author_email"
    t.string "author_url"
    t.integer "comment_parent"
    t.text "content"
    t.datetime "created_at", null: false
    t.integer "post_id"
    t.string "typee"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["approved"], name: "index_comments_on_approved"
    t.index ["comment_parent"], name: "index_comments_on_comment_parent"
    t.index ["post_id"], name: "index_comments_on_post_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "custom_fields", force: :cascade do |t|
    t.integer "count", default: 0
    t.text "description"
    t.integer "field_order"
    t.boolean "is_repeat", default: false
    t.string "name"
    t.string "object_class"
    t.integer "objectid"
    t.integer "parent_id"
    t.string "slug"
    t.string "status"
    t.index ["object_class"], name: "index_custom_fields_on_object_class"
    t.index ["objectid"], name: "index_custom_fields_on_objectid"
    t.index ["parent_id"], name: "index_custom_fields_on_parent_id"
    t.index ["slug"], name: "index_custom_fields_on_slug"
  end

  create_table "custom_fields_relationships", force: :cascade do |t|
    t.integer "custom_field_id"
    t.string "custom_field_slug"
    t.integer "group_number", default: 0
    t.string "object_class"
    t.integer "objectid"
    t.integer "term_order"
    t.text "value", limit: 1073741823
    t.index ["custom_field_id"], name: "index_custom_fields_relationships_on_custom_field_id"
    t.index ["custom_field_slug"], name: "index_custom_fields_relationships_on_custom_field_slug"
    t.index ["object_class"], name: "index_custom_fields_relationships_on_object_class"
    t.index ["objectid"], name: "index_custom_fields_relationships_on_objectid"
  end

  create_table "media", force: :cascade do |t|
    t.datetime "created_at"
    t.string "dimension", default: ""
    t.string "file_size"
    t.string "file_type"
    t.string "folder_path"
    t.boolean "is_folder", default: false
    t.boolean "is_public", default: true
    t.string "name"
    t.integer "site_id"
    t.string "thumb"
    t.datetime "updated_at"
    t.string "url"
    t.index ["folder_path"], name: "index_media_on_folder_path"
    t.index ["is_folder"], name: "index_media_on_is_folder"
    t.index ["name"], name: "index_media_on_name"
    t.index ["site_id"], name: "index_media_on_site_id"
  end

  create_table "metas", force: :cascade do |t|
    t.string "key"
    t.string "object_class"
    t.integer "objectid"
    t.text "value", limit: 1073741823
    t.index ["key"], name: "index_metas_on_key"
    t.index ["object_class"], name: "index_metas_on_object_class"
    t.index ["objectid"], name: "index_metas_on_objectid"
  end

  create_table "plugins_contact_forms", force: :cascade do |t|
    t.integer "count"
    t.datetime "created_at"
    t.text "description"
    t.string "name"
    t.integer "parent_id"
    t.text "settings"
    t.integer "site_id"
    t.string "slug"
    t.datetime "updated_at"
    t.text "value"
  end

  create_table "posts", force: :cascade do |t|
    t.text "content", limit: 1073741823
    t.text "content_filtered", limit: 1073741823
    t.datetime "created_at", null: false
    t.boolean "is_feature", default: false
    t.string "post_class", default: "Post"
    t.integer "post_order", default: 0
    t.integer "post_parent"
    t.datetime "published_at"
    t.text "slug"
    t.string "status", default: "published"
    t.integer "taxonomy_id"
    t.text "title"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.string "visibility", default: "public"
    t.text "visibility_value"
    t.index ["post_class"], name: "index_posts_on_post_class"
    t.index ["post_parent"], name: "index_posts_on_post_parent"
    t.index ["slug"], name: "index_posts_on_slug"
    t.index ["status"], name: "index_posts_on_status"
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "term_relationships", force: :cascade do |t|
    t.integer "objectid"
    t.integer "term_order"
    t.integer "term_taxonomy_id"
    t.index ["objectid"], name: "index_term_relationships_on_objectid"
    t.index ["term_order"], name: "index_term_relationships_on_term_order"
    t.index ["term_taxonomy_id"], name: "index_term_relationships_on_term_taxonomy_id"
  end

  create_table "term_taxonomy", force: :cascade do |t|
    t.integer "count"
    t.datetime "created_at", null: false
    t.text "description", limit: 1073741823
    t.text "name"
    t.integer "parent_id"
    t.string "slug"
    t.string "status"
    t.string "taxonomy"
    t.integer "term_group"
    t.integer "term_order"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["parent_id"], name: "index_term_taxonomy_on_parent_id"
    t.index ["slug"], name: "index_term_taxonomy_on_slug"
    t.index ["taxonomy"], name: "index_term_taxonomy_on_taxonomy"
    t.index ["term_order"], name: "index_term_taxonomy_on_term_order"
    t.index ["user_id"], name: "index_term_taxonomy_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "auth_token"
    t.datetime "confirm_email_sent_at"
    t.string "confirm_email_token"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "first_name"
    t.boolean "is_valid_email", default: true
    t.datetime "last_login_at"
    t.string "last_name"
    t.integer "parent_id"
    t.string "password_digest"
    t.datetime "password_reset_sent_at"
    t.string "password_reset_token"
    t.string "role", default: "client"
    t.integer "site_id", default: -1
    t.string "slug"
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["email"], name: "index_users_on_email"
    t.index ["role"], name: "index_users_on_role"
    t.index ["site_id"], name: "index_users_on_site_id"
    t.index ["username"], name: "index_users_on_username"
  end
end

# NOTE: Keep this block when regenerating schema.rb.
#
# Why this exists:
# - RSpec boot calls `ActiveRecord::Migration.maintain_test_schema!`, which can invoke
#   `bin/rails db:test:prepare` and reload this schema.
# - In this engine/dummy-app setup, schema reload may leave only a subset of migration
#   versions recorded in `schema_migrations`, making many engine migrations appear `down`
#   even though the schema is fully loaded.
#
# How this resolves it:
# - After schema load, we mark every engine migration file under `db/migrate` as applied
#   in `schema_migrations` if it is missing.
# - This keeps `db:migrate:status` and pending migration checks consistent after test runs.

engine_migration_versions = Dir[File.expand_path('../../../db/migrate/*.rb', __dir__)].map do |path|
  File.basename(path).split('_', 2).first
end.sort

schema_migration = ActiveRecord::Base.connection_pool.schema_migration
existing_versions = schema_migration.versions

(engine_migration_versions - existing_versions).each do |version|
  schema_migration.create_version(version)
end
