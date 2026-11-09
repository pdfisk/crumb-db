require "test_helper"

# The forum's set-up (config/initializers/thredded.rb): who moderates, avatars,
# and that Thredded's web pages are not served - the forum is used from the
# IDE, through the JSON forum API (forum_api_test.rb).
class ForumTest < ActionDispatch::IntegrationTest
  setup do
    @board = Thredded::Messageboard.create!(name: "Getting started", description: "First questions")
  end

  test "there are no forum web pages, on any host" do
    %w[api.fastblips.com forum.fastblips.com forum.localhost].each do |host|
      host! host
      get "/#{@board.slug}"
      assert_response :not_found, host
      get "/sign_in"
      assert_response :not_found, host
    end
  end

  test "the API answers JSON with no cookie" do
    host! "api.fastblips.com"
    get "/forum"
    assert_response :success
    assert_equal "application/json", response.media_type
    assert_nil response.headers["Set-Cookie"]
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

  test "no notification email is sent" do
    assert_empty Thredded.notifiers
  end
end
