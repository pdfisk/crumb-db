# What the forum's JSON controllers (ForumApiController, ForumModerationController)
# share: the forum user, Thredded's permission checks, and the JSON shapes the
# IDE reads (javascript/src/ui/forum-client.js).
#
# These answer on the API host with bearer tokens, like the rest of the API.
# They work on Thredded's own records with Thredded's own policies, so a post
# made from the IDE is the same as one made on forum.fastblips.com:
# pre-emptive moderation, locked boards and topics, and who may edit what all
# apply the same way.
module ForumApi
  extend ActiveSupport::Concern

  # Thredded formats posts with a view context for @-mention links; ours
  # (Thredded.user_path in config/initializers/thredded.rb) needs nothing from it.
  NO_VIEW = Object.new.freeze

  included do
    rescue_from Thredded::Errors::MessageboardNotFound, Thredded::Errors::TopicNotFound,
                Thredded::Errors::PostNotFound do |e|
      render json: { error: e.message }, status: :not_found
    end
  end

  private

  # The user Thredded sees: the signed-in user, or Thredded's anonymous user.
  # The development server's local user (local trust) has no account, so it
  # reads as anonymous.
  def forum_user
    @forum_user ||= current_user.is_a?(User) ? current_user : Thredded::NullUser.new
  end

  def signed_in_to_forum?
    !forum_user.thredded_anonymous?
  end

  # A before_action for what needs an account.
  def require_forum_user!
    return if signed_in_to_forum?

    render json: { error: "sign in (File > Sign In) to take part in the forum" }, status: :unauthorized
  end

  def deny!(message)
    raise Authentication::Forbidden, message
  end

  def page_param
    [ params[:page].to_i, 1 ].max
  end

  # "page=last" asks for the last page, wherever that is now.
  def paged(scope)
    if params[:page] == "last"
      last = [ scope.page(1).total_pages, 1 ].max
      scope.page(last)
    else
      scope.page(page_param)
    end
  end

  def page_json(scope)
    { page: scope.current_page, total_pages: [ scope.total_pages, 1 ].max }
  end

  def readable_boards
    Thredded::MessageboardPolicy::Scope.new(forum_user, Thredded::Messageboard.all).resolve
  end

  def find_board
    board = Thredded::Messageboard.friendly_find!(params[:board_id])
    raise Thredded::Errors::MessageboardNotFound unless board_policy(board).read?

    board
  end

  def find_topic(id = params[:id])
    topic = Thredded::Topic.friendly_find!(id)
    raise Thredded::Errors::TopicNotFound unless Thredded::TopicPolicy.new(forum_user, topic).read?

    topic
  end

  def find_post(id = params[:id])
    post = Thredded::Post.find!(id)
    raise Thredded::Errors::PostNotFound unless Thredded::PostPolicy.new(forum_user, post).read?

    post
  end

  def board_policy(board)
    Thredded::MessageboardPolicy.new(forum_user, board)
  end

  # ---- JSON -------------------------------------------------------------------

  def time(value)
    value&.iso8601
  end

  def forum_user_json
    return nil unless signed_in_to_forum?

    detail = forum_user.thredded_user_detail
    {
      name: forum_user.name,
      admin: forum_user.thredded_admin?,
      moderator: forum_user.forum_staff?,
      # pending_moderation: posts wait for a moderator; approved; blocked
      moderation_state: detail.moderation_state
    }
  end

  def author_json(user)
    return { name: "(deleted user)", avatar_url: nil } if user.nil? || user.thredded_anonymous?

    { name: user.name, avatar_url: Thredded.avatar_url.call(user) }
  end

  def board_json(board, unread_counts = nil)
    {
      id: board.id,
      slug: board.slug,
      name: board.name,
      description: board.description.to_s,
      locked: board.locked?,
      topics_count: board.topics_count,
      posts_count: board.posts_count,
      unread_topics_count: unread_counts && (unread_counts[board.id] || 0),
      last_post_at: time(board.last_topic&.last_post_at),
      last_user: board.last_topic&.last_user&.then { |u| u.thredded_anonymous? ? nil : u.name },
      can_post: signed_in_to_forum? && board_policy(board).post?,
      can_moderate: signed_in_to_forum? && board_policy(board).moderate?
    }
  end

  # A topic in a list. read_state and follow come from
  # Thredded::Topic.with_read_and_follow_states.
  def topic_json(topic, read_state: nil, follow: nil)
    {
      id: topic.id,
      slug: topic.slug,
      title: topic.title,
      board: { slug: topic.messageboard.slug, name: topic.messageboard.name },
      user: author_json(topic.user)[:name],
      last_user: author_json(topic.last_user)[:name],
      posts_count: topic.posts_count,
      created_at: time(topic.created_at),
      last_post_at: time(topic.last_post_at),
      sticky: topic.sticky?,
      locked: topic.locked?,
      moderation_state: topic.moderation_state,
      unread: signed_in_to_forum? && read_state ? !read_state.read? : nil,
      following: signed_in_to_forum? ? follow.present? : nil
    }
  end

  # A topic as it is shown: with what this user may do to it.
  def topic_detail_json(topic)
    policy = Thredded::TopicPolicy.new(forum_user, topic)
    reply = Thredded::Post.new(postable: topic, messageboard: topic.messageboard)
    following = signed_in_to_forum? && Thredded::UserTopicFollow.exists?(topic_id: topic.id, user_id: forum_user.id)
    topic_json(topic, follow: following.presence).merge(
      can_reply: signed_in_to_forum? && Thredded::PostPolicy.new(forum_user, reply).create?,
      can_edit: signed_in_to_forum? && policy.update?,
      can_delete: signed_in_to_forum? && policy.destroy?,
      can_moderate: signed_in_to_forum? && policy.moderate?
    )
  end

  def post_json(post, first_post_id: nil)
    policy = Thredded::PostPolicy.new(forum_user, post)
    first = first_post_id ? post.id == first_post_id : post.first_post_in_topic?
    {
      id: post.id,
      topic_id: post.postable_id,
      user: author_json(post.user),
      content: post.content,
      html: post.filtered_content(NO_VIEW).to_str,
      created_at: time(post.created_at),
      updated_at: time(post.updated_at),
      moderation_state: post.moderation_state,
      first: first,
      can_edit: signed_in_to_forum? && policy.update?,
      can_delete: signed_in_to_forum? && !first && policy.update?,
      can_moderate: signed_in_to_forum? && policy.moderate?
    }
  end

  def errors_json(errors)
    { errors: errors.to_hash(false) }
  end
end
