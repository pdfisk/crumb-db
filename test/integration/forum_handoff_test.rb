require "test_helper"

# The IDE's Forum button: a one-time code from the API, redeemed on the forum.
class ForumHandoffTest < ActionDispatch::IntegrationTest
  FORUM = Rails.configuration.x.forum_host

  setup { @alice = make_user("alice") }

  def handoff(user = @alice, **params)
    host! "api.fastblips.com"
    post "/forum_handoff", params: params, headers: bearer(user), as: :json
    assert_response :created
    response.parsed_body["url"]
  end

  def visit(url)
    uri = URI(url)
    host! uri.host
    get "#{uri.path}?#{uri.query}"
  end

  test "the API gives a signed-in user a one-time forum link" do
    url = handoff
    assert_match %r{\Ahttps?://#{Regexp.escape(FORUM)}/sso\?code=[\w-]{40,}\z}, url
    assert_equal 1, ForumHandoff.count
    code = Rack::Utils.parse_query(URI(url).query)["code"]
    assert_equal ForumHandoff.digest(code), ForumHandoff.last.code_digest, "only the digest is stored"
    assert_not_equal code, ForumHandoff.last.code_digest
  end

  test "no link without a sign-in" do
    host! "api.fastblips.com"
    with_local_trust_off { post "/forum_handoff", as: :json }
    assert_response :unauthorized
  end

  test "the link signs the user in to the forum and goes to the front page" do
    visit handoff
    assert_redirected_to "/"
    follow_redirect!
    assert_select ".forum-user", "alice"
  end

  test "the link can carry a local return_to, never another site" do
    visit handoff(return_to: "/getting-started")
    assert_redirected_to "/getting-started"

    url = handoff(return_to: "//evil.example")
    assert_no_match(/return_to/, url)
  end

  test "a link works only once" do
    url = handoff
    visit url
    delete "/sign_out"
    visit url
    assert_redirected_to %r{/sign_in}
    follow_redirect!
    assert_select "[role=alert]", /expired or was already used/
    assert_select ".forum-user", false
  end

  test "a link expires after a minute" do
    url = handoff
    travel ForumHandoff::LIFETIME + 1.second do
      visit url
    end
    assert_redirected_to %r{/sign_in}
  end

  test "an unknown or missing code signs nobody in" do
    host! FORUM
    get "/sso?code=nonsense"
    assert_redirected_to %r{/sign_in}
    get "/sso"
    assert_redirected_to %r{/sign_in}
  end

  test "redeeming is atomic: the same code cannot be spent twice" do
    _record, code = ForumHandoff.issue(@alice)
    assert_equal @alice, ForumHandoff.redeem(code)
    assert_nil ForumHandoff.redeem(code)
  end

  test "old codes are tidied away when new ones are issued" do
    ForumHandoff.issue(@alice)
    travel 2.hours do
      ForumHandoff.issue(@alice)
      assert_equal 1, ForumHandoff.count
    end
  end

  test "sso is only on the forum host" do
    _record, code = ForumHandoff.issue(@alice)
    host! "api.fastblips.com"
    get "/sso?code=#{code}"
    assert_response :not_found
  end

  private

  def with_local_trust_off
    was = Rails.configuration.x.local_trust
    Rails.configuration.x.local_trust = false
    yield
  ensure
    Rails.configuration.x.local_trust = was
  end
end
