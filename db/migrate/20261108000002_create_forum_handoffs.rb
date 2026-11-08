# One-time codes that sign an IDE user in to the forum (see ForumHandoff).
class CreateForumHandoffs < ActiveRecord::Migration[8.0]
  def change
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
