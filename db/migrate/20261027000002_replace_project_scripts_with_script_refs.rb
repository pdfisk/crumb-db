# A project's scripts are now a JSON list of "<owner>/<name>" strings kept in
# the project's own record (an empty owner, "/name", is a script in the shared
# space), instead of rows in project_scripts that point at scripts by id. There
# are no foreign keys between projects and scripts: a name whose script has
# since been deleted or renamed is simply left in the list.
class ReplaceProjectScriptsWithScriptRefs < ActiveRecord::Migration[8.0]
  def up
    add_column :projects, :scripts, :jsonb, null: false, default: []

    refs = select_rows(<<~SQL.squish)
      SELECT ps.project_id, COALESCE(u.name, '') || '/' || COALESCE(ps.name, s.name)
      FROM project_scripts ps
      JOIN scripts s ON s.id = ps.script_id
      LEFT JOIN users u ON u.id = s.owner_id
      ORDER BY ps.project_id, ps.position, ps.id
    SQL
    refs.group_by(&:first).each do |project_id, rows|
      execute "UPDATE projects SET scripts = #{quote(rows.map(&:last).to_json)}::jsonb WHERE id = #{project_id.to_i}"
    end

    drop_table :project_scripts
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "the snapshots in project_scripts are gone"
  end
end
