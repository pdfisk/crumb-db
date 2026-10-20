# Sign-in: a password digest on users, and the tokens a client sends after
# signing in. Only a SHA-256 digest of each token is stored, so a copy of the
# database cannot be used to sign in as anyone.
#
# Existing users have no password (password_digest is null) and cannot sign in
# until one is set: bin/rails "users:set_password[name]".
class AddAuthentication < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :password_digest, :string, if_not_exists: true

    create_table :api_tokens, if_not_exists: true do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :last_used_at
      t.timestamps
      t.index :token_digest, unique: true
    end
  end
end
