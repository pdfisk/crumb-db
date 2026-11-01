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

  test "a project keeps its own copies of its scripts' source" do
    ball = { name: "Ball", language: "python", content: "print(1)", priority: 3, compiled_code: "{}" }
    paddle = { name: "Paddle", language: "python", content: "print(2)" }
    post "/projects", params: { project: { name: "mine", scripts: [ paddle, ball ] } }, headers: bearer(@bob), as: :json
    assert_response :created
    assert_equal [
      { "name" => "Paddle", "language" => "python", "content" => "print(2)" },
      { "name" => "Ball", "language" => "python", "content" => "print(1)", "priority" => 3, "compiled_code" => "{}" },
    ], response.parsed_body["scripts"], "in order, as sent"
    id = response.parsed_body["id"]

    patch "/projects/#{id}", params: { project: { scripts: [ paddle.merge(content: "print(3)") ] } }, headers: bearer(@bob), as: :json
    assert_response :success
    assert_equal [ "print(3)" ], response.parsed_body["scripts"].map { |s| s["content"] }
    patch "/projects/#{id}", params: { project: { scripts: [] } }, headers: bearer(@bob), as: :json
    assert_equal [], response.parsed_body["scripts"]
  end

  test "a new project may have no scripts, and an empty list is stored as one" do
    post "/projects", params: { project: { name: "empty", scripts: [] } }, headers: bearer(@bob), as: :json
    assert_response :created
    assert_equal [], response.parsed_body["scripts"]
    post "/projects", params: { project: { name: "bare" } }, headers: bearer(@bob), as: :json
    assert_response :created
    assert_equal [], response.parsed_body["scripts"]
    assert_equal "[]", Project.connection.select_value("SELECT scripts FROM projects WHERE name = 'bare'")
  end

  test "a project's scripts need a name, a known language and names of their own" do
    bad = [
      [ { language: "python", content: "x" } ],
      [ { name: "a", language: "cobol", content: "x" } ],
      [ { name: "a", language: "python", content: "x" }, { name: "A", language: "python", content: "y" } ],
      [ { name: "a", language: "python", content: "x", priority: 9 } ],
      [ { name: "a", language: "python", content: "x", compiled_code: "not json" } ],
      [ "bob/b" ],
    ]
    bad.each_with_index do |scripts, i|
      post "/projects", params: { project: { name: "bad#{i}", scripts: scripts } }, headers: bearer(@bob), as: :json
      assert_response :unprocessable_entity, scripts.inspect
    end
  end

  test "the copy made for a project is the script record as it is" do
    script = Script.create!(name: "Ball", language: "python", content: "print(1)", priority: 2, owner: @bob)
    assert_equal({ "name" => "Ball", "language" => "python", "content" => "print(1)", "priority" => 2 }, Project.script_copy(script))
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
