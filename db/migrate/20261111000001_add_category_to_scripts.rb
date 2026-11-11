# What kind of program a script is: game, getting-started, tutorial or widget
# (Script::CATEGORIES). Existing
# scripts become games.
class AddCategoryToScripts < ActiveRecord::Migration[8.0]
  def change
    add_column :scripts, :category, :string, default: "game", null: false
    add_index :scripts, :category
  end
end
