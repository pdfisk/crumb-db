# Names belong to a user: two users can each have an app, a screen or a
# composite called "login", and one user cannot have two.
#
# A record with no owner is in the shared space. Shared screens keep the
# rule they had (one per name). Shared apps keep none, because the tables
# they came from allowed the same name twice.
class NamespaceByOwner < ActiveRecord::Migration[8.0]
  def change
    add_reference :viewport, :owner, foreign_key: { to_table: :users }

    remove_index :viewport, :name, unique: true, name: "index_viewport_on_name"
    add_index :viewport, :name, unique: true, where: "owner_id IS NULL",
                                name: "index_viewport_on_name_shared"
    add_index :viewport, %i[owner_id name], unique: true, where: "owner_id IS NOT NULL",
                                            name: "index_viewport_on_owner_and_name"

    add_index :apps, %i[owner_id name], unique: true, where: "owner_id IS NOT NULL",
                                        name: "index_apps_on_owner_and_name"
  end
end
