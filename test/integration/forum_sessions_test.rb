require "test_helper"

class ForumSessionsTest < ActionDispatch::IntegrationTest
  setup { host! Rails.configuration.x.forum_host }

  test "the sign-in page is HTML on the forum host" do
    get "/sign_in"
    assert_response :success
    assert_match "text/html", response.media_type
    assert_select "form[action='/sign_in']"
  end

  test "signing in with the right password starts a session" do
    make_user("alice")
    post "/sign_in", params: { name: "Alice", password: ApiHelpers::PASSWORD }
    assert_redirected_to "/"
    follow_redirect!
    assert_response :success
    assert_select ".forum-user", "alice"
  end

  test "a wrong password is refused and says so" do
    make_user("alice")
    post "/sign_in", params: { name: "alice", password: "wrong password" }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", /Wrong name or password/
  end

  test "signing in goes back to a local return_to, never to another site" do
    make_user("alice")
    post "/sign_in", params: { name: "alice", password: ApiHelpers::PASSWORD, return_to: "/some/topic" }
    assert_redirected_to "/some/topic"

    delete "/sign_out"
    post "/sign_in", params: { name: "alice", password: ApiHelpers::PASSWORD, return_to: "//evil.example" }
    assert_redirected_to "/"
  end

  test "signing out ends the session" do
    make_user("alice")
    post "/sign_in", params: { name: "alice", password: ApiHelpers::PASSWORD }
    delete "/sign_out"
    assert_redirected_to "/"
    follow_redirect!
    assert_select ".forum-user", false
  end

  test "forum pages are not served on other hosts" do
    host! "api.fastblips.com"
    get "/sign_in"
    assert_response :not_found
  end

  test "the API still ignores the forum cookie" do
    make_user("alice")
    post "/sign_in", params: { name: "alice", password: ApiHelpers::PASSWORD }
    with_local_trust_off do
      get "/session"
    end
    assert_response :unauthorized
    assert_match "application/json", response.media_type
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
