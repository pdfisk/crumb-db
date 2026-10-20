require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "registering signs the new user in" do
    post "/users", params: { user: { name: "alice", password: ApiHelpers::PASSWORD } }, as: :json
    assert_response :created
    token = response.parsed_body["token"]
    assert token.present?
    assert_nil response.parsed_body["password_digest"]

    get "/session", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :success
    assert_equal "alice", response.parsed_body.dig("user", "name")
  end

  test "registering needs a password of at least 8 characters" do
    post "/users", params: { user: { name: "alice" } }, as: :json
    assert_response :unprocessable_entity

    post "/users", params: { user: { name: "alice", password: "short" } }, as: :json
    assert_response :unprocessable_entity
    assert User.where(name: "alice").none?
  end

  test "a name is taken whatever its case" do
    make_user("alice")
    post "/users", params: { user: { name: "ALICE", password: ApiHelpers::PASSWORD } }, as: :json
    assert_response :unprocessable_entity
  end

  test "registering works even with a stale token" do
    post "/users", params: { user: { name: "bob", password: ApiHelpers::PASSWORD } }, as: :json,
                   headers: { "Authorization" => "Bearer nonsense" }
    assert_response :created
  end

  test "signing in gives a token that works" do
    make_user("alice")
    post "/session", params: { session: { name: "Alice", password: ApiHelpers::PASSWORD } }, as: :json
    assert_response :created
    token = response.parsed_body["token"]

    get "/session", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :success
    assert_equal false, response.parsed_body.dig("user", "admin")
  end

  test "a wrong password, an unknown name and a user with no password are refused alike" do
    make_user("alice")
    User.insert({ name: "legacy", created_at: Time.current, updated_at: Time.current })   # as before sign-in existed

    [ %w[alice wrong-password], %w[nobody whatever-it-is], [ "legacy", ApiHelpers::PASSWORD ] ].each do |name, password|
      post "/session", params: { session: { name: name, password: password } }, as: :json
      assert_response :unauthorized, "#{name} should be refused"
      assert_equal "wrong name or password", response.parsed_body["error"]
    end
  end

  test "signing out ends the token" do
    headers = bearer(make_user("alice"))
    delete "/session", headers: headers
    assert_response :no_content

    get "/session", headers: headers
    assert_response :unauthorized
  end

  test "a token that is not valid is refused even for a public read" do
    get "/scripts", headers: { "Authorization" => "Bearer nonsense" }
    assert_response :unauthorized
  end

  test "an expired token is refused" do
    user = make_user("alice")
    record, token = ApiToken.issue(user)
    record.update!(expires_at: 1.minute.ago)
    get "/scripts", headers: { "Authorization" => "Bearer #{token}" }
    assert_response :unauthorized
  end

  test "only a digest of the token is stored" do
    _record, token = ApiToken.issue(make_user("alice"))
    assert ApiToken.where(token_digest: token).none?
    assert ApiToken.where(token_digest: ApiToken.digest(token)).one?
  end

  test "no session without a token" do
    get "/session"
    assert_response :unauthorized
  end
end
