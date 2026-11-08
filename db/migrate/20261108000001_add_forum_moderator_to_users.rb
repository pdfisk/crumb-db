# Forum moderators (Thredded.moderator_column). Administrators (ADMIN_USERS)
# moderate as well; see User#forum_staff?.
class AddForumModeratorToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :forum_moderator, :boolean, default: false, null: false
  end
end
