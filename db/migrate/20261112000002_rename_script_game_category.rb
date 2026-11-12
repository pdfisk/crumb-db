# The scripts' mobile games are called mobile-game, as the projects' are
# (Project::CATEGORIES), instead of game. Existing game scripts are renamed,
# and new scripts default to mobile-game.
class RenameScriptGameCategory < ActiveRecord::Migration[8.0]
  def up
    execute "UPDATE scripts SET category = 'mobile-game' WHERE category = 'game'"
    change_column_default :scripts, :category, from: "game", to: "mobile-game"
  end

  def down
    execute "UPDATE scripts SET category = 'game' WHERE category = 'mobile-game'"
    change_column_default :scripts, :category, from: "mobile-game", to: "game"
  end
end
