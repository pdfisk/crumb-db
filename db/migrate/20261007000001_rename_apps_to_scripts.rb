# The apps table becomes scripts, with two new columns:
#
#   shared        true when the owner has shared the script; false for every
#                 existing row
#   project_name  the project a script belongs to; null for none
#
# rename_table also renames the primary key, the id sequence and the indexes
# that have Rails' default names. The owner-and-name index and the check
# constraints were named by hand, so they are renamed here: nothing in the
# database is left called apps.
#
# The model is still App and the address is still /apps (see app/models/app.rb).
class RenameAppsToScripts < ActiveRecord::Migration[8.0]
  CHECKS = %w[language_known visibility_known version_positive priority_range].freeze

  def up
    rename_table :apps, :scripts
    rename_index :scripts, "index_apps_on_owner_and_name", "index_scripts_on_owner_and_name"
    CHECKS.each do |check|
      execute "ALTER TABLE scripts RENAME CONSTRAINT apps_#{check} TO scripts_#{check}"
    end

    add_column :scripts, :shared, :boolean, null: false, default: false
    add_column :scripts, :project_name, :string
  end

  def down
    remove_column :scripts, :project_name
    remove_column :scripts, :shared

    CHECKS.each do |check|
      execute "ALTER TABLE scripts RENAME CONSTRAINT scripts_#{check} TO apps_#{check}"
    end
    rename_index :scripts, "index_scripts_on_owner_and_name", "index_apps_on_owner_and_name"
    rename_table :scripts, :apps
  end
end
