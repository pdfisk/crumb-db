require "test_helper"

class ForumSeedTest < ActiveSupport::TestCase
  def seed
    load Rails.root.join("db/seeds/forum.rb")
  end

  test "creates three groups and seven boards, in order" do
    seed
    assert_equal %w[FastBlips Learning Community], Thredded::MessageboardGroup.order(:position).pluck(:name)
    assert_equal %w[announcements ideas bugs getting-started python widgets show-and-tell],
                 Thredded::Messageboard.order(:position).pluck(:slug)
    python = Thredded::Messageboard.find_by!(slug: "python")
    assert_equal "Learning", Thredded::MessageboardGroup.find(python.messageboard_group_id).name
  end

  test "only Announcements is locked to moderators" do
    seed
    assert_equal %w[announcements], Thredded::Messageboard.where(locked: true).pluck(:slug)
  end

  test "running it again changes nothing, and keeps edits made on the site" do
    seed
    Thredded::Messageboard.find_by!(slug: "bugs").update!(name: "Bug reports")
    seed
    assert_equal 3, Thredded::MessageboardGroup.count
    assert_equal 7, Thredded::Messageboard.count
    assert_equal "Bug reports", Thredded::Messageboard.find_by!(slug: "bugs").name
  end
end
