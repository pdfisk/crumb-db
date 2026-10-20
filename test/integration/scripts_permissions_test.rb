require "test_helper"

class ScriptsPermissionsTest < ActionDispatch::IntegrationTest
  setup do
    @alice = make_user("alice")
    @bob = make_user("bob")
    @public = make_script(@alice, "pub")
    @unlisted = make_script(@alice, "side", visibility: "unlisted")
    @private = make_script(@alice, "secret", visibility: "private")
    @shared = make_script(nil, "legacy")
  end

  def body(name = "new", **extra)
    { script: { name: name, language: "basic", content: "Print 2" }.merge(extra) }
  end

  test "anyone can list the public scripts, but not the unlisted or private ones" do
    get "/scripts"
    assert_response :success
    assert_equal %w[legacy pub], names(response.parsed_body)

    get "/scripts", headers: bearer(@bob)
    assert_equal %w[legacy pub], names(response.parsed_body)
  end

  test "the owner's listing shows all their scripts" do
    get "/scripts", headers: bearer(@alice)
    assert_equal %w[legacy pub secret side], names(response.parsed_body)
  end

  test "an unlisted script is found by owner and name, or by its address" do
    get "/scripts", params: { owner: "alice", name: "side" }
    assert_equal %w[side], names(response.parsed_body)

    get "/scripts/#{@unlisted.id}"
    assert_response :success
  end

  test "a private script is not found by anyone but its owner" do
    get "/scripts/#{@private.id}"
    assert_response :not_found
    get "/scripts/#{@private.id}", headers: bearer(@bob)
    assert_response :not_found
    patch "/scripts/#{@private.id}", params: body("x"), headers: bearer(@bob), as: :json
    assert_response :not_found
    get "/scripts", params: { owner: "alice", name: "secret" }, headers: bearer(@bob)
    assert_equal [], names(response.parsed_body)

    get "/scripts/#{@private.id}", headers: bearer(@alice)
    assert_response :success
  end

  test "changing anything needs a signed-in user" do
    post "/scripts", params: body, as: :json
    assert_response :unauthorized
    patch "/scripts/#{@public.id}", params: body("x"), as: :json
    assert_response :unauthorized
    delete "/scripts/#{@public.id}"
    assert_response :unauthorized
  end

  test "a new script goes in the caller's space" do
    post "/scripts", params: body, headers: bearer(@bob), as: :json
    assert_response :created
    assert_equal "bob", response.parsed_body["owner"]
  end

  test "a script cannot be put in someone else's space, or an unknown one" do
    post "/scripts", params: body("a", owner: "alice"), headers: bearer(@bob), as: :json
    assert_response :forbidden
    post "/scripts", params: body("b", owner: "nobody"), headers: bearer(@bob), as: :json
    assert_response :forbidden
    assert_nil User.find_by(name: "nobody")
  end

  test "owner_id in a body is ignored" do
    post "/scripts", params: body("c", owner_id: @alice.id), headers: bearer(@bob), as: :json
    assert_response :created
    assert_equal "bob", response.parsed_body["owner"]
  end

  test "only the owner can change or delete a script" do
    patch "/scripts/#{@public.id}", params: body("renamed"), headers: bearer(@bob), as: :json
    assert_response :forbidden
    delete "/scripts/#{@public.id}", headers: bearer(@bob)
    assert_response :forbidden
    assert_equal "pub", @public.reload.name

    patch "/scripts/#{@public.id}", params: body("renamed"), headers: bearer(@alice), as: :json
    assert_response :success
    assert_equal "renamed", @public.reload.name
    delete "/scripts/#{@public.id}", headers: bearer(@alice)
    assert_response :no_content
  end

  test "a script cannot be handed to another user by changing its owner" do
    patch "/scripts/#{@public.id}", params: { script: { owner: "bob" } }, headers: bearer(@alice), as: :json
    assert_response :forbidden
    assert_equal @alice.id, @public.reload.owner_id
  end

  test "the shared space is read-only except for administrators" do
    patch "/scripts/#{@shared.id}", params: body("x"), headers: bearer(@bob), as: :json
    assert_response :forbidden
    post "/scripts", params: body("y", owner: ""), headers: bearer(@bob), as: :json
    assert_response :forbidden

    with_admins("bob") do
      patch "/scripts/#{@shared.id}", params: body("x"), headers: bearer(@bob), as: :json
      assert_response :success
      post "/scripts", params: body("y", owner: ""), headers: bearer(@bob), as: :json
      assert_response :created
      assert_nil response.parsed_body["owner"]
    end
  end

  test "the old per-language addresses are protected the same way" do
    post "/basic_sources", params: { basic_source: { name: "old", content: "Print 3" } }, as: :json
    assert_response :unauthorized
    post "/basic_sources", params: { basic_source: { name: "old", content: "Print 3" } }, headers: bearer(@bob), as: :json
    assert_response :created
    assert_equal "bob", response.parsed_body["owner"]
  end
end
