# Sharing is a property of a project, not of a script: a project lists the
# owner's scripts and those in the shared space, and is shared as a whole.
class RemoveSharedFromScripts < ActiveRecord::Migration[8.0]
  def change
    remove_column :scripts, :shared, :boolean, null: false, default: false
  end
end
