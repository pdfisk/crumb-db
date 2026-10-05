# Accounts: the owners of apps. Names and e-mail addresses are unique
# whatever their case. There are no credentials here yet: how users sign in
# is still to be decided.
class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users, if_not_exists: true do |t|
      t.string :name, null: false
      t.string :email

      t.timestamps
    end
    add_index :users, "lower(name)", unique: true, name: "index_users_on_lower_name", if_not_exists: true
    add_index :users, "lower(email)", unique: true, name: "index_users_on_lower_email", if_not_exists: true
  end
end
