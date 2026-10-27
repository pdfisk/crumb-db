require "test_helper"

# A development server asked from this machine needs no sign-in (see
# Authentication#local_trust?). Tests run with it off, so each one switches it on.
class LocalTrustTest < ActionDispatch::IntegrationTest
  def with_local_trust(on = true)
    was = Rails.configuration.x.local_trust
    Rails.configuration.x.local_trust = on
    yield
  ensure
    Rails.configuration.x.local_trust = was
  end

  test "without local trust, writes still need sign-in" do
    post "/scripts", params: { script: { name: "hello", language: "basic", content: "Print 1" } }, as: :json
    assert_response :unauthorized
  end

  test "with local trust, an anonymous local request can create in a named space" do
    with_local_trust do
      post "/scripts", params: { script: { owner: "peter", name: "hello", language: "basic", content: "Print 1" } }, as: :json
      assert_response :created
      assert_equal "peter", response.parsed_body["owner"]
      assert User.exists?(name: "peter")
    end
  end

  test "with local trust, a body with no owner creates in the shared space" do
    with_local_trust do
      post "/scripts", params: { script: { name: "hello", language: "basic", content: "Print 1" } }, as: :json
      assert_response :created
      assert_nil response.parsed_body["owner"]
    end
  end

  test "with local trust, other people's and private records can be read and changed" do
    alice = make_user("alice")
    script = make_script(alice, "secret", visibility: "private")
    with_local_trust do
      get "/scripts/#{script.id}"
      assert_response :success

      patch "/scripts/#{script.id}", params: { script: { content: "Print 2" } }, as: :json
      assert_response :success
      assert_equal "Print 2", script.reload.content

      delete "/scripts/#{script.id}"
      assert_response :no_content
    end
  end

  test "with local trust, a stale token is ignored" do
    with_local_trust do
      get "/scripts", headers: { "Authorization" => "Bearer nonsense" }
      assert_response :success
    end
  end

  test "GET /session names the local user" do
    with_local_trust do
      get "/session"
      assert_response :success
      assert_equal "local", response.parsed_body.dig("user", "name")
    end
  end

  test "a real token still signs in as that user" do
    alice = make_user("alice")
    with_local_trust do
      get "/session", headers: bearer(alice)
      assert_equal "alice", response.parsed_body.dig("user", "name")
    end
  end

  test "requests from another address are not trusted" do
    with_local_trust do
      post "/scripts", params: { script: { name: "hello", language: "basic", content: "Print 1" } }, as: :json,
                       env: { "REMOTE_ADDR" => "203.0.113.5" }
      assert_response :unauthorized
    end
  end
end
