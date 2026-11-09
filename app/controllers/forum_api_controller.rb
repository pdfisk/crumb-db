# The forum as JSON, for the IDE's Forum window (javascript/src/ui/windows/
# forum-window.js). Everything a member does on forum.fastblips.com can be done
# here: read boards and topics, search, post topics and replies, edit and
# delete them, follow topics. Moderation is ForumModerationController.
#
# Reading is open to everyone (as on the forum's pages); posting needs a
# bearer token (POST /session). Thredded's policies decide the rest.
#
#   GET    /forum                          the user and the boards, in their groups
#   GET    /forum/boards/:board/topics     a board's topics (?page=)
#   POST   /forum/boards/:board/topics     a new topic   {"topic": {"title", "content", "sticky"?, "locked"?}}
#   GET    /forum/topics?q=...             topics found in every board (?page=)
#   GET    /forum/topics?filter=unread     topics with posts not yet read
#   GET    /forum/topics/:id               a topic and a page of its posts (?page=, page=last); marks them read
#   PATCH  /forum/topics/:id               {"topic": {"title"?, "locked"?, "sticky"?, "board"?}}
#   DELETE /forum/topics/:id               (administrators)
#   POST   /forum/topics/:id/follow        follow; DELETE to stop
#   POST   /forum/topics/:id/posts         a reply   {"post": {"content"}}
#   PATCH  /forum/posts/:id                {"post": {"content"}}
#   DELETE /forum/posts/:id                (not a topic's first post: delete the topic)
#   GET    /forum/posts/:id/quote          {"content": "> quoted text"}
#   POST   /forum/preview                  {"content"} -> {"html"}: what a post will look like
#
# Topics and boards are named by slug or id. A topic, post or board this user
# may not read is 404, as if it did not exist.
class ForumApiController < ApiController
  include ForumApi

  WRITES = %i[create_topic update_topic destroy_topic follow unfollow create_post update_post destroy_post].freeze

  before_action :require_forum_user!, only: WRITES

  # Learners are new to forums: a burst of posts is held back, per user.
  rate_limit to: 5, within: 10.minutes, only: :create_topic, by: -> { current_user&.id || request.remote_ip },
             with: -> { render json: { error: "you have started several topics just now: wait a few minutes" }, status: :too_many_requests }
  rate_limit to: 10, within: 2.minutes, only: :create_post, by: -> { current_user&.id || request.remote_ip },
             with: -> { render json: { error: "you have posted several replies just now: wait a minute" }, status: :too_many_requests }
  rate_limit to: 60, within: 1.minute, only: :preview, by: -> { current_user&.id || request.remote_ip },
             with: -> { render json: { error: "too many previews: wait a minute" }, status: :too_many_requests }

  # GET /forum
  def index
    boards = readable_boards.ordered_by_position.includes(:group, last_topic: :last_user).to_a
    unread = signed_in_to_forum? ? Thredded::Messageboard.unread_topics_counts(
      user: forum_user,
      topics_scope: Thredded::TopicPolicy::Scope.new(forum_user, Thredded::Topic.all).resolve
    ) : nil
    groups = boards.group_by(&:group).sort_by { |group, _| [ group ? 0 : 1, group&.position || 0 ] }
    render json: {
      user: forum_user_json,
      groups: groups.map do |group, list|
        { name: group&.name || "Boards", boards: list.map { |b| board_json(b, unread) } }
      end
    }
  end

  # GET /forum/boards/:board_id/topics
  def topics
    board = find_board
    scope = paged(visible_topics(board.topics).order_sticky_first.order_recently_posted_first
                    .includes(:messageboard, :user, :last_user))
    render json: { board: board_json(board), topics: topics_with_states(scope), **page_json(scope) }
  end

  # GET /forum/topics?q=  or  ?filter=unread
  def search
    scope = visible_topics(Thredded::Topic.where(messageboard_id: readable_boards.select(:id)))
    if params[:filter] == "unread"
      return require_forum_user! unless signed_in_to_forum?

      scope = scope.unread(forum_user).order_followed_first(forum_user).order_recently_posted_first
    else
      query = params[:q].to_s.strip
      return render json: { error: "say what to search for" }, status: :bad_request if query.empty?

      scope = scope.search_query(query).order_recently_posted_first
    end
    scope = paged(scope.includes(:messageboard, :user, :last_user))
    render json: { topics: topics_with_states(scope), **page_json(scope) }
  end

  # GET /forum/topics/:id
  def show
    topic = find_topic
    posts = paged(Thredded::PostPolicy::Scope.new(forum_user, topic.posts).resolve
                    .order_oldest_first.includes(:user, :messageboard))
    list = posts.to_a
    Thredded::UserTopicReadState.touch!(forum_user.id, list.last) if signed_in_to_forum? && list.any?
    first_id = topic.first_post&.id
    render json: {
      topic: topic_detail_json(topic),
      posts: list.map { |p| post_json(p, first_post_id: first_id) },
      **page_json(posts)
    }
  end

  # POST /forum/boards/:board_id/topics
  def create_topic
    board = find_board
    body = params.require(:topic)
    moderator = board_policy(board).moderate?
    form = Thredded::TopicForm.new(
      title: body[:title].to_s.strip, content: body[:content].to_s,
      locked: moderator && truthy(body[:locked]), sticky: moderator && truthy(body[:sticky]),
      user: forum_user, messageboard: board
    )
    deny!("you cannot start topics in #{board.name}") unless Thredded::TopicPolicy.new(forum_user, form.topic).create?
    return render json: errors_json(form.errors), status: :unprocessable_entity unless form.save

    render json: { topic: topic_detail_json(form.topic), post: post_json(form.post, first_post_id: form.post.id) },
           status: :created
  end

  # PATCH /forum/topics/:id
  def update_topic
    topic = find_topic
    body = params.require(:topic)
    policy = Thredded::TopicPolicy.new(forum_user, topic)
    deny!("only its author or a moderator can change this topic") unless policy.update?

    topic.title = body[:title].to_s.strip if body.key?(:title)
    if body.key?(:locked) || body.key?(:sticky)
      deny!("only a moderator can lock or pin a topic") unless policy.moderate?
      topic.locked = truthy(body[:locked]) if body.key?(:locked)
      topic.sticky = truthy(body[:sticky]) if body.key?(:sticky)
    end
    if body[:board].present?
      target = Thredded::Messageboard.friendly_find!(body[:board])
      if target != topic.messageboard
        deny!("only a moderator can move a topic") unless policy.moderate?
        deny!("you cannot post in #{target.name}") unless board_policy(target).post?
        topic.messageboard = target
      end
    end
    return render json: errors_json(topic.errors), status: :unprocessable_entity unless topic.save

    render json: { topic: topic_detail_json(topic.reload) }
  end

  # DELETE /forum/topics/:id
  def destroy_topic
    topic = find_topic
    deny!("only an administrator can delete a topic") unless Thredded::TopicPolicy.new(forum_user, topic).destroy?

    topic.destroy!
    head :no_content
  end

  # POST /forum/topics/:id/follow
  def follow
    topic = find_topic
    Thredded::UserTopicFollow.create_unless_exists(forum_user.id, topic.id)
    render json: { following: true }
  end

  # DELETE /forum/topics/:id/follow
  def unfollow
    topic = find_topic
    Thredded::UserTopicFollow.find_by(topic_id: topic.id, user_id: forum_user.id)&.destroy
    render json: { following: false }
  end

  # POST /forum/topics/:id/posts
  def create_post
    topic = find_topic
    form = Thredded::PostForm.new(user: forum_user, topic: topic,
                                  post_params: { content: params.require(:post)[:content].to_s })
    unless Thredded::PostPolicy.new(forum_user, form.post).create?
      deny!(topic.locked? ? "this topic is locked" : "you cannot reply in #{topic.messageboard.name}")
    end
    return render json: errors_json(form.post.errors), status: :unprocessable_entity unless form.save

    render json: { post: post_json(form.post), topic: topic_detail_json(topic.reload) }, status: :created
  end

  # PATCH /forum/posts/:id
  def update_post
    post = find_post
    deny!("only its author or a moderator can change this post") unless Thredded::PostPolicy.new(forum_user, post).update?
    return render json: errors_json(post.errors), status: :unprocessable_entity \
      unless post.update(content: params.require(:post)[:content].to_s)

    render json: { post: post_json(post) }
  end

  # DELETE /forum/posts/:id
  def destroy_post
    post = find_post
    policy = Thredded::PostPolicy.new(forum_user, post)
    deny!("the first post goes only with its topic") if post.first_post_in_topic?
    deny!("only its author or a moderator can delete this post") unless policy.destroy?

    post.destroy!
    head :no_content
  end

  # GET /forum/posts/:id/quote
  def quote
    post = find_post
    render json: { content: "#{author_json(post.user)[:name]} wrote:\n#{Thredded::ContentFormatter.quote_content(post.content.to_s)}" }
  end

  # POST /forum/preview
  def preview
    content = params[:content].to_s
    return render json: { error: "a post is at most 65,000 characters" }, status: :unprocessable_entity if content.size > 65_000

    render json: { html: Thredded::ContentFormatter.new(NO_VIEW).format_content(content).to_str }
  end

  private

  def visible_topics(scope)
    Thredded::TopicPolicy::Scope.new(forum_user, scope).resolve
  end

  def topics_with_states(scope)
    scope.with_read_and_follow_states(forum_user).map do |topic, read_state, follow|
      topic_json(topic, read_state: read_state, follow: follow)
    end
  end

  def truthy(value)
    ActiveModel::Type::Boolean.new.cast(value) || false
  end
end
