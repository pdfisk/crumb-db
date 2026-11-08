# The IDE's way into the forum, already signed in.
#
#   POST /forum_handoff   body {"return_to": "/getting-started"} (optional)
#     201 {"url": "https://forum.fastblips.com/sso?code=...", "expires_at": ...}
#     Open the url within a minute; it works once. 401 without a valid token.
#     422 for the development server's local user, who has no account.
class ForumHandoffsController < ApiController
  before_action :require_login!

  rate_limit to: 30, within: 1.minute, only: :create,
             with: -> { render json: { error: "too many tries: wait a minute" }, status: :too_many_requests }

  # POST /forum_handoff
  def create
    if local_trust_user?
      return render json: { error: "sign in with an account to open the forum signed in" }, status: :unprocessable_entity
    end

    record, code = ForumHandoff.issue(current_user)
    query = { code: code }
    return_to = ForumHandoff.local_path(params[:return_to])
    query[:return_to] = return_to if return_to
    render json: { url: "#{forum_origin}/sso?#{query.to_query}", expires_at: record.expires_at }, status: :created
  end

  private

  # https://forum.fastblips.com in production; in development the forum host
  # on this server's port, e.g. http://forum.localhost:3000.
  def forum_origin
    host = Rails.configuration.x.forum_host
    port = [ 80, 443 ].include?(request.port) ? "" : ":#{request.port}"
    "#{request.protocol}#{host}#{port}"
  end
end
