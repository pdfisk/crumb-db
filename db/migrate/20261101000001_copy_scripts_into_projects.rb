# A project's scripts become the project's own copies of the scripts' source,
# instead of "<owner>/<name>" references to records in the scripts table. Each
# reference is replaced by a copy of that script as it is now:
#
#   { "name", "language", "content", "priority", "compiled_code" }
#
# A reference whose script has gone is dropped, as are repeats of a name. The
# column stays JSON text in a text column.
class CopyScriptsIntoProjects < ActiveRecord::Migration[8.0]
  def up
    owners = select_rows("SELECT id, name FROM users").to_h { |id, name| [ name.to_s.downcase, id ] }
    select_rows("SELECT id, scripts FROM projects").each do |project_id, text|
      list = JSON.parse(text.presence || "[]") rescue []
      seen = {}
      copies = list.filter_map do |entry|
        next entry if entry.is_a?(Hash)   # already a copy

        owner, name = entry.to_s.split("/", 2)
        next if name.to_s.strip.empty?

        script = find_script(owner.to_s.strip, name.strip, owners)
        next unless script

        copy = { "name" => script["name"], "language" => script["language"], "content" => script["content"].to_s }
        copy["priority"] = script["priority"].to_i unless script["priority"].nil?
        copy["compiled_code"] = script["compiled"] unless script["compiled"].to_s.empty?
        copy
      end
      copies = copies.select { |c| seen[c["name"].to_s.downcase] ? false : (seen[c["name"].to_s.downcase] = true) }
      execute "UPDATE projects SET scripts = #{quote(copies.to_json)} WHERE id = #{project_id.to_i}"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "the copies may have changed since; there is nothing to point back at"
  end

  private

  # The script an "owner/name" named (ignoring case); an empty owner is the shared space.
  def find_script(owner, name, owners)
    owner_sql = if owner.empty?
      "owner_id IS NULL"
    else
      id = owners[owner.downcase]
      return nil unless id

      "owner_id = #{id.to_i}"
    end
    select_all(<<~SQL.squish).to_a.first
      SELECT name, language, content, priority, compiled FROM scripts
      WHERE #{owner_sql} AND LOWER(name) = #{quote(name.downcase)}
      ORDER BY (name = #{quote(name)}) DESC, id
      LIMIT 1
    SQL
  end
end
