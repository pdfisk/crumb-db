# The base of the forum's controllers: HTML pages with a cookie session, on the
# forum host (config.x.forum_host). Thredded's controllers inherit from it too
# (Thredded::ApplicationController < ::ApplicationController), which is why the
# HTML base has this name and the JSON API's base is ApiController.
#
# It does not include Authentication, so bearer tokens and local trust never
# apply here: a forum page knows only who signed in to the forum.
class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  layout "forum"

  helper_method :current_forum_user, :forum_root_path

  private

  # The signed-in user, or nil. Thredded asks for it by this name
  # (Thredded.current_user_method).
  def current_forum_user
    return @current_forum_user if defined?(@current_forum_user)

    @current_forum_user = session[:user_id] && User.find_by(id: session[:user_id])
  end

  # The forum's front page: Thredded is mounted at "/" on the forum host.
  def forum_root_path
    "/"
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

  # Where to go after signing in: a path on this host, else the front page.
  def safe_return_to(path)
    ForumHandoff.local_path(path) || forum_root_path
  end
end
