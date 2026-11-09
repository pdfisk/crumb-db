# The one-time codes that signed an IDE user in to the forum's web pages. The
# forum is now used only from the IDE (the JSON forum API), so they are gone.
class DropForumHandoffs < ActiveRecord::Migration[8.0]
  def up
    drop_table :forum_handoffs, if_exists: true
  end

  def down
    create_table :forum_handoffs do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :code_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.timestamps
    end
    add_index :forum_handoffs, :code_digest, unique: true
  end
end
