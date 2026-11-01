# Whether a user may save records when browsing the database (the Database
# windows). A new column, so every existing user starts without it; an
# administrator grants it, e.g. in bin/rails console:
#   User.find_by(name: "peter").update!(has_database_write_permission: true)
class AddDatabaseWritePermissionToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :has_database_write_permission, :boolean, null: false, default: false
  end
end
