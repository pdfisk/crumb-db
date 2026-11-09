require "test_helper"

# The forum as JSON, for the IDE (ForumApiController, ForumModerationController).
class ForumApiTest < ActionDispatch::IntegrationTest
  setup do
    host! "api.fastblips.com"
    @group = Thredded::MessageboardGroup.create!(name: "Learning")
    @board = Thredded::Messageboard.create!(name: "Getting started", description: "First questions", group: @group)
    @news = Thredded::Messageboard.create!(name: "Announcements", locked: true)
    @alice = make_user("alice")
    @bob = make_user("bob")
    @mod = make_user("mod", forum_moderator: true)
    approve(@alice, @bob)
  end

  def approve(*users)
    users.each { |u| u.thredded_user_detail.update!(moderation_state: :approved) }
  end

  def json = response.parsed_body

  def start_topic(user = @alice, board: @board, title: "How do I draw a circle?", content: "With **Canvas**?")
    post "/forum/boards/#{board.slug}/topics", params: { topic: { title: title, content: content } },
                                               headers: bearer(user), as: :json
    json
  end

  test "anyone can list the boards, in their groups" do
    get "/forum"
    assert_response :success
    assert_nil json["user"]
    names = json["groups"].map { |g| g["name"] }
    assert_equal [ "Learning", "Boards" ], names
    board = json["groups"][0]["boards"][0]
    assert_equal "getting-started", board["slug"]
    assert_equal false, board["can_post"]
    assert_nil board["unread_topics_count"]
  end

  test "a signed-in user sees who they are and where they may post" do
    get "/forum", headers: bearer(@alice)
    assert_equal "alice", json["user"]["name"]
    assert_equal "approved", json["user"]["moderation_state"]
    boards = json["groups"].flat_map { |g| g["boards"] }.index_by { |b| b["slug"] }
    assert boards["getting-started"]["can_post"]
    assert_not boards["announcements"]["can_post"], "Announcements is locked to moderators"
  end

  test "starting a topic, reading it and replying" do
    created = start_topic
    assert_response :created
    slug = created["topic"]["slug"]
    assert_includes created["post"]["html"], "<strong>Canvas</strong>"

    get "/forum/topics/#{slug}", headers: bearer(@bob)
    assert_response :success
    assert_equal "How do I draw a circle?", json["topic"]["title"]
    assert_equal 1, json["posts"].size
    assert json["posts"][0]["first"]
    assert json["topic"]["can_reply"]
    assert_not json["posts"][0]["can_edit"], "bob cannot edit alice's post"

    post "/forum/topics/#{slug}/posts", params: { post: { content: "Use canvas.circle(x, y, r)" } },
                                        headers: bearer(@bob), as: :json
    assert_response :created
    assert_equal 2, json["topic"]["posts_count"]

    get "/forum/topics/#{slug}?page=last"
    assert_equal %w[alice bob], json["posts"].map { |p| p["user"]["name"] }
  end

  test "posting needs a sign-in" do
    post "/forum/boards/#{@board.slug}/topics", params: { topic: { title: "Hi", content: "Hello" } }, as: :json
    assert_response :unauthorized
    assert_equal 0, Thredded::Topic.count
  end

  test "only moderators start topics in a locked board" do
    start_topic(@alice, board: @news)
    assert_response :forbidden
    start_topic(@mod, board: @news, title: "Welcome")
    assert_response :created
  end

  test "a new user's posts wait for a moderator" do
    carol = make_user("carol")
    slug = start_topic(carol, title: "First question")["topic"]["slug"]
    assert_equal "pending_moderation", json["post"]["moderation_state"]

    get "/forum/boards/#{@board.slug}/topics", headers: bearer(@bob)
    assert_empty json["topics"], "others do not see it yet"
    get "/forum/boards/#{@board.slug}/topics", headers: bearer(carol)
    assert_equal [ "First question" ], json["topics"].map { |t| t["title"] }, "its author does"

    get "/forum/moderation/pending", headers: bearer(@mod)
    assert_response :success
    pending = json["posts"]
    assert_equal [ "First question" ], pending.map { |p| p.dig("topic", "title") }

    post "/forum/moderation/posts/#{pending[0]['id']}", params: { moderation_state: "approved" },
                                                       headers: bearer(@mod), as: :json
    assert_response :success
    assert_equal "approved", json["post"]["moderation_state"]
    assert carol.reload.thredded_user_detail.approved?, "approving the post approves its author"

    get "/forum/topics/#{slug}", headers: bearer(@bob)
    assert_response :success
  end

  test "moderation is for moderators" do
    get "/forum/moderation/pending", headers: bearer(@alice)
    assert_response :forbidden
    get "/forum/moderation/users", headers: bearer(@mod)
    assert_response :success
    assert_includes json["users"].map { |u| u["name"] }, "alice"
  end

  test "a moderator can block and approve a user" do
    patch "/forum/moderation/users/#{@bob.id}", params: { moderation_state: "blocked" }, headers: bearer(@mod), as: :json
    assert_response :success
    assert @bob.reload.thredded_user_detail.blocked?
    patch "/forum/moderation/users/#{@mod.id}", params: { moderation_state: "blocked" }, headers: bearer(@mod), as: :json
    assert_response :forbidden
  end

  test "authors edit their posts; others cannot" do
    created = start_topic
    id = created["post"]["id"]
    patch "/forum/posts/#{id}", params: { post: { content: "Edited" } }, headers: bearer(@bob), as: :json
    assert_response :forbidden
    patch "/forum/posts/#{id}", params: { post: { content: "Edited" } }, headers: bearer(@alice), as: :json
    assert_response :success
    assert_equal "Edited", json["post"]["content"]
  end

  test "a reply can be deleted, the first post cannot" do
    slug = start_topic["topic"]["slug"]
    first = json["post"]["id"]
    post "/forum/topics/#{slug}/posts", params: { post: { content: "Me too" } }, headers: bearer(@bob), as: :json
    reply = json["post"]["id"]
    delete "/forum/posts/#{first}", headers: bearer(@alice)
    assert_response :forbidden
    delete "/forum/posts/#{reply}", headers: bearer(@bob)
    assert_response :no_content
  end

  test "only moderators lock, pin or move topics" do
    slug = start_topic["topic"]["slug"]
    other = Thredded::Messageboard.create!(name: "Show and tell")
    patch "/forum/topics/#{slug}", params: { topic: { locked: true } }, headers: bearer(@alice), as: :json
    assert_response :forbidden
    patch "/forum/topics/#{slug}", params: { topic: { title: "Drawing circles" } }, headers: bearer(@alice), as: :json
    assert_response :success
    patch "/forum/topics/#{slug}", params: { topic: { locked: true, sticky: true, board: other.slug } },
                                   headers: bearer(@mod), as: :json
    assert_response :success
    assert json["topic"]["locked"]
    assert_equal "show-and-tell", json["topic"]["board"]["slug"]

    post "/forum/topics/#{slug}/posts", params: { post: { content: "Late reply" } }, headers: bearer(@bob), as: :json
    assert_response :forbidden
  end

  test "following, unread topics and search" do
    slug = start_topic["topic"]["slug"]
    post "/forum/topics/#{slug}/follow", headers: bearer(@bob)
    assert json["following"]

    get "/forum/topics?filter=unread", headers: bearer(@bob)
    assert_equal [ slug ], json["topics"].map { |t| t["slug"] }
    assert json["topics"][0]["unread"]
    get "/forum/topics/#{slug}", headers: bearer(@bob)
    assert json["topic"]["following"]
    get "/forum/topics?filter=unread", headers: bearer(@bob)
    assert_empty json["topics"], "reading the topic marks it read"

    get "/forum/topics?q=circle"
    assert_equal [ slug ], json["topics"].map { |t| t["slug"] }
    get "/forum/topics"
    assert_response :bad_request
  end

  test "preview and quote" do
    post "/forum/preview", params: { content: "# Hi\n<script>alert(1)</script>" }, headers: bearer(@alice), as: :json
    assert_response :success
    assert_includes json["html"], "<h1"
    assert_not_includes json["html"], "<script"

    id = start_topic(content: "Line one")["post"]["id"]
    get "/forum/posts/#{id}/quote"
    assert_equal "alice wrote:\n> Line one\n\n", json["content"]
  end

  test "an unknown topic is not found" do
    get "/forum/topics/no-such-topic"
    assert_response :not_found
  end
end
