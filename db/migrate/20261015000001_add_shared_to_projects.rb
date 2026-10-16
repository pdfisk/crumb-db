# Projects get a shared flag, as scripts have: true when the owner has shared
# the project, false (the default) for every existing project.
class AddSharedToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :shared, :boolean, null: false, default: false
  end
end
