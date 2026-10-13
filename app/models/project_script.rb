# A script's place in a project: the join between the two, with the script's
# position (from 0) in the project's list.
class ProjectScript < ApplicationRecord
  belongs_to :project
  belongs_to :script

  validates :script_id, uniqueness: { scope: :project_id }
end
