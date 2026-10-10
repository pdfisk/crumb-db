# Projects: a name, a description, an owner and the scripts in it.
#
# A project's scripts are the ones in its space (the same owner, or none)
# whose project_name is the project's name: the column added to scripts by
# RenameAppsToScripts. A script is in at most one project.
#
# Like screens, a name is unique in each user's space and in the shared one.
class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.string :name, null: false
      t.text :description
      t.references :owner, foreign_key: { to_table: :users }

      t.timestamps
    end
    add_index :projects, :name, unique: true, where: "owner_id IS NULL",
                                name: "index_projects_on_name_shared"
    add_index :projects, %i[owner_id name], unique: true, where: "owner_id IS NOT NULL",
                                            name: "index_projects_on_owner_and_name"

    # Finding a project's scripts.
    add_index :scripts, %i[owner_id project_name], name: "index_scripts_on_owner_and_project_name"
  end
end
