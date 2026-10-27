require "test_helper"

class ProjectsAndViewportsTest < ActionDispatch::IntegrationTest
  setup do
    @alice = make_user("alice")
    @bob = make_user("bob")
    @mine = Project.create!(name: "private-one", owner: @alice)
    @shared = Project.create!(name: "open-one", owner: @alice, shared: true)
    @legacy = Project.create!(name: "legacy-one")
  end

  test "unshared projects are visible only to their owner" do
    get "/projects"
    assert_equal %w[legacy-one open-one], names(response.parsed_body)
    get "/projects", headers: bearer(@bob)
    assert_equal %w[legacy-one open-one], names(response.parsed_body)
    get "/projects", headers: bearer(@alice)
    assert_equal %w[legacy-one open-one private-one], names(response.parsed_body)

    get "/projects/#{@mine.id}"
    assert_response :not_found
    get "/projects/#{@mine.id}", headers: bearer(@bob)
    assert_response :not_found
    get "/projects/#{@mine.id}", headers: bearer(@alice)
    assert_response :success
    get "/projects/#{@shared.id}"
    assert_response :success
  end

  test "only the owner can change a project, and signing in is needed to make one" do
    post "/projects", params: { project: { name: "x" } }, as: :json
    assert_response :unauthorized

    patch "/projects/#{@shared.id}", params: { project: { description: "mine now" } }, headers: bearer(@bob), as: :json
    assert_response :forbidden
    delete "/projects/#{@shared.id}", headers: bearer(@bob)
    assert_response :forbidden

    patch "/projects/#{@shared.id}", params: { project: { description: "updated" } }, headers: bearer(@alice), as: :json
    assert_response :success
  end

  test "a new project goes in the caller's space and cannot name another's" do
    post "/projects", params: { project: { name: "bobs" } }, headers: bearer(@bob), as: :json
    assert_response :created
    assert_equal "bob", response.parsed_body["owner"]

    post "/projects", params: { project: { name: "sneaky", owner: "alice" } }, headers: bearer(@bob), as: :json
    assert_response :forbidden
  end

  test "a project can list only scripts its owner may use" do
    post "/projects", params: { project: { name: "grab", scripts: [ "alice/alices-private" ] } }, headers: bearer(@bob), as: :json
    assert_response :unprocessable_entity
    post "/projects", params: { project: { name: "junk", scripts: [ "no-slash" ] } }, headers: bearer(@bob), as: :json
    assert_response :unprocessable_entity

    post "/projects", params: { project: { name: "mine", scripts: [ "bob/b", "/common", "bob/b" ] } }, headers: bearer(@bob), as: :json
    assert_response :created
    assert_equal [ "bob/b", "/common" ], response.parsed_body["scripts"], "in order, without repeats; a script need not exist"
    id = response.parsed_body["id"]
    patch "/projects/#{id}", params: { project: { scripts: [] } }, headers: bearer(@bob), as: :json
    assert_equal [], response.parsed_body["scripts"]
  end

  test "screens are readable by anyone and changeable only by their owner" do
    content = { format: "fastblip-viewport", version: 1, widgets: [], windows: [] }
    post "/viewports", params: { viewport: { name: "home", content: content } }, as: :json
    assert_response :unauthorized

    post "/viewports", params: { viewport: { name: "home", content: content } }, headers: bearer(@alice), as: :json
    assert_response :created
    id = response.parsed_body["id"]
    assert_equal "alice", response.parsed_body["owner"]

    get "/viewports/#{id}"
    assert_response :success
    patch "/viewports/#{id}", params: { viewport: { name: "taken" } }, headers: bearer(@bob), as: :json
    assert_response :forbidden
    delete "/viewports/#{id}", headers: bearer(@bob)
    assert_response :forbidden
    delete "/viewports/#{id}", headers: bearer(@alice)
    assert_response :no_content
  end
end
