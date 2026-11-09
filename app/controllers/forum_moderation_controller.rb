# Moderating the forum from the IDE (the Forum Moderation window), for
# administrators (ADMIN_USERS) and forum moderators (users.forum_moderator):
# the same work as Thredded's moderation pages.
#
#   GET   /forum/moderation/pending       posts waiting for approval, oldest first (?page=)
#   GET   /forum/moderation/activity      every post, newest first (?page=)
#   GET   /forum/moderation/history       what moderators decided, newest first (?page=)
#   POST  /forum/moderation/posts/:id     {"moderation_state": "approved" | "blocked"}
#   GET   /forum/moderation/users         users, pending first (?q= a name prefix, ?page=)
#   PATCH /forum/moderation/users/:id     {"moderation_state": "approved" | "blocked" | "pending_moderation"}
#
# Approving a new user's post approves the user, so their later posts appear at
# once; blocking does the opposite (Thredded::ModeratePost).
class ForumModerationController < ApiController
  include ForumApi

  before_action :require_forum_user!
  before_action :require_moderator!

  # GET /forum/moderation/pending
  def pending
    posts_page(moderatable_posts.pending_moderation.order_oldest_first)
  end

  # GET /forum/moderation/activity
  def activity
    posts_page(moderatable_posts.order_newest_first)
  end

  # GET /forum/moderation/history
  def history
    records = moderation_records.order(created_at: :desc, id: :desc)
                                .preload(:messageboard, :moderator, post: :postable).page(page_param)
    render json: {
      records: records.map do |r|
        {
          id: r.id,
          post_id: r.post_id,
          topic: r.post&.postable&.title,
          board: r.messageboard&.name,
          user: r.post_user_name,
          moderator: r.moderator&.name,
          previous_moderation_state: r.previous_moderation_state,
          moderation_state: r.moderation_state,
          content: r.post_content.to_s.truncate(500),
          created_at: time(r.created_at)
        }
      end,
      **page_json(records)
    }
  end

  # POST /forum/moderation/posts/:id
  def moderate_post
    state = params[:moderation_state].to_s
    return render json: { error: "moderation_state is approved or blocked" }, status: :bad_request \
      unless %w[approved blocked].include?(state)

    post = moderatable_posts.find_by(id: params[:id])
    return render json: { error: "no such post" }, status: :not_found unless post

    Thredded::ModeratePost.run!(post: post, moderation_state: state, moderator: forum_user) if post.moderation_state != state
    render json: { post: moderation_post_json(post.reload) }
  end

  # GET /forum/moderation/users
  def users
    scope = User.eager_load(:thredded_user_detail).merge(
      Thredded::UserDetail.order(Arel.sql("COALESCE(thredded_user_details.moderation_state, 0) ASC, " \
                                          "thredded_user_details.moderation_state_changed_at DESC"))
    ).order(:name)
    query = params[:q].to_s.strip
    scope = DbTextSearch::CaseInsensitive.new(scope, :name).prefix(query) if query.present?
    scope = scope.page(page_param)
    render json: { users: scope.map { |u| moderation_user_json(u) }, **page_json(scope) }
  end

  # PATCH /forum/moderation/users/:id
  def moderate_user
    state = params[:moderation_state].to_s
    return render json: { error: "moderation_state is approved, blocked or pending_moderation" }, status: :bad_request \
      unless Thredded::UserDetail.moderation_states.include?(state)

    user = User.find(params[:id])
    deny!("you cannot change your own standing") if user.id == forum_user.id
    user.thredded_user_detail.update!(moderation_state: state)
    render json: { user: moderation_user_json(user) }
  end

  private

  def require_moderator!
    deny!("only moderators can do this") unless forum_user.forum_staff?
  end

  def moderatable_boards
    @moderatable_boards ||= forum_user.thredded_can_moderate_messageboards
  end

  def moderatable_posts
    moderatable_boards == Thredded::Messageboard.all ? Thredded::Post.all : Thredded::Post.where(messageboard_id: moderatable_boards)
  end

  def moderation_records
    if moderatable_boards == Thredded::Messageboard.all
      Thredded::PostModerationRecord.all
    else
      Thredded::PostModerationRecord.where(messageboard_id: moderatable_boards)
    end
  end

  def posts_page(scope)
    scope = scope.includes(:user, :messageboard, :postable).page(page_param)
    render json: { posts: scope.map { |p| moderation_post_json(p) }, **page_json(scope) }
  end

  # A post with the topic and board it is in, as the moderation lists show it.
  def moderation_post_json(post)
    post_json(post).merge(
      topic: { id: post.postable.id, slug: post.postable.slug, title: post.postable.title },
      board: { slug: post.messageboard.slug, name: post.messageboard.name },
      user_moderation_state: post.user&.thredded_user_detail&.moderation_state
    )
  end

  def moderation_user_json(user)
    detail = user.thredded_user_detail
    {
      id: user.id,
      name: user.name,
      moderation_state: detail.moderation_state,
      moderation_state_changed_at: time(detail.moderation_state_changed_at),
      posts_count: detail.posts_count.to_i,
      topics_count: detail.topics_count.to_i,
      last_seen_at: time(detail.last_seen_at),
      staff: user.forum_staff?
    }
  end
end
