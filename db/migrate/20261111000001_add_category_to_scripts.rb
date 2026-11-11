# What kind of program a script is (a game, a tool, an example...). Existing
# scripts become games.
class AddCategoryToScripts < ActiveRecord::Migration[8.0]
  def change
    add_column :scripts, :category, :string, default: "game", null: false
    add_index :scripts, :category
  end
end
