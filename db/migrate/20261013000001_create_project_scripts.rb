# A project's scripts become an ordered list in a join table, instead of the
# scripts' own project_name column.
#
#   project_scripts  project_id, script_id and the script's position (from 0)
#                    in the project. A script can be in several projects, and
#                    a project can hold scripts owned by other users, if they
#                    are shared.
#
# Existing projects keep their scripts, by name; scripts.project_name and its
# index are dropped. Rolling back puts project_name back, for a script in
# several projects the name of any one of them.
class CreateProjectScripts < ActiveRecord::Migration[8.0]
  def up
    create_table :project_scripts do |t|
      t.references :project, null: false, foreign_key: { on_delete: :cascade }
      t.references :script, null: false, foreign_key: { on_delete: :cascade }
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :project_scripts, %i[project_id script_id], unique: true
    add_index :project_scripts, %i[project_id position]

    execute <<~SQL
      INSERT INTO project_scripts (project_id, script_id, position, created_at, updated_at)
      SELECT p.id, s.id,
             ROW_NUMBER() OVER (PARTITION BY p.id ORDER BY lower(s.name), s.id) - 1,
             NOW(), NOW()
      FROM projects p
      JOIN scripts s ON s.project_name = p.name AND s.owner_id IS NOT DISTINCT FROM p.owner_id
    SQL

    remove_index :scripts, name: "index_scripts_on_owner_and_project_name"
    remove_column :scripts, :project_name
  end

  def down
    add_column :scripts, :project_name, :string
    add_index :scripts, %i[owner_id project_name], name: "index_scripts_on_owner_and_project_name"

    execute <<~SQL
      UPDATE scripts s SET project_name = p.name
      FROM project_scripts ps
      JOIN projects p ON p.id = ps.project_id
      WHERE ps.script_id = s.id AND s.owner_id IS NOT DISTINCT FROM p.owner_id
    SQL

    drop_table :project_scripts
  end
end
