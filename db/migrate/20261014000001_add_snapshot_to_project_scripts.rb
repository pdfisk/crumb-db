# A project keeps a snapshot of each of its scripts, taken whenever the
# project is saved: the script's name, language, source, compiled code,
# priority and version, in project_scripts beside the link to the script. A
# project can then be loaded and run as it was saved, whatever has since been
# done to the scripts themselves. Existing projects get a snapshot of their
# scripts as they are now.
class AddSnapshotToProjectScripts < ActiveRecord::Migration[8.0]
  def up
    change_table :project_scripts do |t|
      t.string :name
      t.string :language
      t.text :content
      t.text :compiled
      t.integer :priority
      t.integer :version
    end

    execute <<~SQL
      UPDATE project_scripts ps
      SET name = s.name, language = s.language, content = s.content,
          compiled = s.compiled, priority = s.priority, version = s.version
      FROM scripts s
      WHERE s.id = ps.script_id
    SQL
  end

  def down
    change_table :project_scripts do |t|
      t.remove :name, :language, :content, :compiled, :priority, :version
    end
  end
end
