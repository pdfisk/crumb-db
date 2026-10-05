# One apps table in place of basic_source and python_source: the same
# columns, plus the language (which table the row used to be in), an owner,
# a visibility and a version.
#
# Every row of the two old tables is copied across, keeping its timestamps;
# ids are new, since the old tables each counted from 1. The old tables are
# left as they were, unused, as a backup: drop them once apps is trusted.
class CreateApps < ActiveRecord::Migration[8.0]
  SOURCES = { "basic" => :basic_source, "python" => :python_source }.freeze

  def up
    create_table :apps do |t|
      t.string :name, null: false
      t.text :content
      t.string :language, null: false
      t.references :owner, foreign_key: { to_table: :users }
      t.string :visibility, null: false, default: "public"
      t.integer :version, null: false, default: 1
      t.integer :priority, null: false, default: 3
      t.text :compiled

      t.timestamps
    end
    add_index :apps, :name
    add_index :apps, %i[language name]
    add_check_constraint :apps, "language IN ('basic', 'python')", name: "apps_language_known"
    add_check_constraint :apps, "visibility IN ('public', 'unlisted', 'private')", name: "apps_visibility_known"
    add_check_constraint :apps, "version >= 1", name: "apps_version_positive"
    add_check_constraint :apps, "priority BETWEEN 1 AND 5", name: "apps_priority_range"

    SOURCES.each do |language, table|
      next unless table_exists?(table)

      execute <<~SQL
        INSERT INTO apps (name, content, language, priority, compiled, created_at, updated_at)
        SELECT COALESCE(NULLIF(btrim(name), ''), 'untitled-' || id),
               content, #{quote(language)}, priority, compiled, created_at, updated_at
        FROM #{quote_table_name(table)}
        ORDER BY id
      SQL
    end
  end

  def down
    drop_table :apps
  end
end
