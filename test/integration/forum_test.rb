require "test_helper"

# The forum (Thredded) on the forum host: pages, sign-in and permissions.
class ForumTest < ActionDispatch::IntegrationTest
  setup do
    host! Rails.configuration.x.forum_host
    @board = Thredded::Messageboard.create!(name: "Getting started", description: "First questions")
  end

  test "anyone can read the boards" do
    get "/"
    assert_response :success
    assert_select "body", /Getting started/
    assert_select "a", "Sign in"
  end

  test "a board's page uses the FastBlips layout" do
    get "/#{@board.slug}"
    assert_response :success
    assert_select ".forum-mast"
  end

  test "a signed-in user sees their name on Thredded's pages" do
    make_user("alice")
    post "/sign_in", params: { name: "alice", password: ApiHelpers::PASSWORD }
    get "/#{@board.slug}"
    assert_response :success
    assert_select ".forum-user", "alice"
  end

  test "the forum is not served on other hosts" do
    host! "api.fastblips.com"
    get "/#{@board.slug}"
    assert_response :not_found
  end

  test "administrators come from ADMIN_USERS and moderate every board" do
    alice = make_user("alice")
    bob = make_user("bob")
    with_admins("alice") do
      assert alice.thredded_admin?
      assert_not bob.thredded_admin?
      assert_includes alice.thredded_can_moderate_messageboards, @board
      assert_empty bob.thredded_can_moderate_messageboards
    end
  end

  test "forum moderators moderate, but are not administrators" do
    mod = make_user("mod", forum_moderator: true)
    assert mod.thredded_can_moderate_messageboard?(@board)
    assert_not mod.thredded_admin?
  end

  test "avatars are made here, not fetched from Gravatar" do
    url = Thredded.avatar_url.call(make_user("alice"))
    assert url.start_with?("data:image/svg+xml;base64,")
    assert_includes Base64.decode64(url.split(",", 2).last), ">A<"
  end
end
