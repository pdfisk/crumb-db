# What kind of project it is (Project::CATEGORIES): development (the default,
# for work in progress), desktop-game, desktop-app, mobile-game or mobile-app.
# The mobile start page lists the shared mobile-game projects. Existing
# projects become development.
class AddCategoryToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :category, :string, default: "development", null: false
    add_index :projects, :category
  end
end
