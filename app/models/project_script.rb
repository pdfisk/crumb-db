# A script's place in a project: the join between the two, with the script's
# position (from 0) in the project's list, and a snapshot of the script as it
# was when the project was last saved (name, language, source, compiled code,
# priority and version), so the project holds what it runs.
class ProjectScript < ApplicationRecord
  SNAPSHOT_FIELDS = %w[name language content compiled priority version].freeze

  belongs_to :project
  belongs_to :script

  validates :script_id, uniqueness: { scope: :project_id }

  # Copies the script's current state into the snapshot.
  def snapshot!(from = script)
    update!(SNAPSHOT_FIELDS.to_h { |field| [field, from[field]] })
  end

  # The snapshot as JSON, with the compiled code under the client's name.
  def snapshot_hash
    { "name" => name, "language" => language, "content" => content, "compiled_code" => compiled,
      "priority" => priority, "version" => version }
  end
end
