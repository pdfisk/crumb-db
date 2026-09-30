# Saved FastBlip screens: a program's Viewport as JSON (Viewport save / load
# in the crumb client). One record per name.
class CreateViewport < ActiveRecord::Migration[8.0]
  def change
    create_table :viewport, if_not_exists: true do |t|
      t.string :name, null: false
      t.jsonb :content, null: false, default: {}

      t.timestamps
    end
    add_index :viewport, :name, unique: true, if_not_exists: true
  end
end
