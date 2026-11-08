# The base of the forum's controllers: HTML pages with a cookie session, on the
# forum host (config.x.forum_host). Unlike ApplicationController it does not
# include Authentication, so bearer tokens and local trust never apply here:
# a forum page knows only who signed in to the forum.
#
# Thredded's controllers will inherit from it (Thredded.parent_controller).
class ForumBaseController < ActionController::Base
  protect_from_forgery with: :exception
  layout "forum"

  helper_method :current_forum_user

  private

  # The signed-in user, or nil.
  def current_forum_user
    return @current_forum_user if defined?(@current_forum_user)

    @current_forum_user = session[:user_id] && User.find_by(id: session[:user_id])
  end

  # Starts a fresh session for this user (a new session id, so one fixed
  # before signing in is no use to anyone).
  def forum_sign_in(user)
    reset_session
    session[:user_id] = user.id
    @current_forum_user = user
  end

  def forum_sign_out
    reset_session
    @current_forum_user = nil
  end

  # A before_action for pages that need someone signed in.
  def require_forum_sign_in!
    return if current_forum_user

    redirect_to forum_sign_in_path(return_to: request.fullpath)
  end

  # Where to go after signing in: a path on this host, else the front page.
  # "//host" and "/\\host" are refused: browsers treat them as other sites.
  def safe_return_to(path)
    path = path.to_s
    path.start_with?("/") && !path.start_with?("//", "/\\") ? path : forum_root_path
  end
end
