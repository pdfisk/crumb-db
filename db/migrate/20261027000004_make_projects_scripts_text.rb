# A project's scripts are kept as JSON text (a list of "<owner>/<name>"
# strings) in a plain text column, "[]" when it has none; the model reads and
# writes it as a list.
class MakeProjectsScriptsText < ActiveRecord::Migration[8.0]
  def up
    execute "ALTER TABLE projects ALTER COLUMN scripts DROP DEFAULT"
    execute "ALTER TABLE projects ALTER COLUMN scripts TYPE text USING scripts::text"
    execute "ALTER TABLE projects ALTER COLUMN scripts SET DEFAULT '[]'"
  end

  def down
    execute "ALTER TABLE projects ALTER COLUMN scripts DROP DEFAULT"
    execute "ALTER TABLE projects ALTER COLUMN scripts TYPE jsonb USING scripts::jsonb"
    execute "ALTER TABLE projects ALTER COLUMN scripts SET DEFAULT '[]'::jsonb"
  end
end
