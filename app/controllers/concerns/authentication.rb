# Who is asking, and what they may change.
#
# A client signs in (POST /session) and sends the token it gets as
#
#   Authorization: Bearer <token>
#
# with each request. A request with no Authorization header is anonymous: it
# may read what is public. A request with a token that is not valid (unknown,
# expired or signed out) is refused with 401 whatever it asks, so a client
# learns that it must sign in again.
#
# Reading follows each record's visibility (see the models' visible_to?);
# changing needs a signed-in user who owns the record. Records in the shared
# space (no owner) can be changed only by administrators (User#admin?).
#
# Local trust: a development server asked from this machine needs no sign-in.
# A request with no valid token is then treated as the local user, who may read
# and change anything (see local_trust?). It never applies in production or to
# requests from another address; set LOCAL_REQUIRE_LOGIN=1 to turn it off.
module Authentication
  extend ActiveSupport::Concern

  # Raised when the user may not do what was asked; answered with 403.
  class Forbidden < StandardError; end

  included do
    before_action :authenticate
    rescue_from(Forbidden) { |e| render json: { error: e.message }, status: :forbidden }
  end

  private

  def current_user
    @current_user
  end

  def current_token
    @current_token
  end

  # Finds the user from the Authorization header, if there is one.
  def authenticate
    header = request.authorization.to_s
    return use_local_user if header.empty? && local_trust?

    return if header.empty?

    token = header[/\ABearer\s+(\S+)\z/i, 1]
    @current_token = ApiToken.find_live(token)
    if @current_token
      @current_user = @current_token.user
      stamp_token
    elsif local_trust?
      use_local_user   # a stale token from an earlier sign-in does not matter here
    else
      render json: { error: "the token is not valid or has expired: sign in again" }, status: :unauthorized
    end
  end

  # Whether this request is trusted without signing in: the server is in
  # development, the request comes from this machine and local trust has not
  # been switched off (config.x.local_trust, i.e. LOCAL_REQUIRE_LOGIN=1).
  def local_trust?
    Rails.configuration.x.local_trust == true && request.local?
  end

  def local_trust_user?
    current_user.is_a?(LocalUser)
  end

  def use_local_user
    @current_user = LocalUser.instance
  end

  # last_used_at, at most every five minutes, so reads do not write.
  def stamp_token
    seen = @current_token.last_used_at
    @current_token.update_column(:last_used_at, Time.current) if seen.nil? || seen < 5.minutes.ago
  end

  # A before_action for what needs someone signed in.
  def require_login!
    render json: { error: "sign in required" }, status: :unauthorized unless current_user
  end

  # Whether the user may change this record: it is theirs, or it is in the
  # shared space and they are an administrator.
  def can_modify?(record)
    return false unless current_user
    return true if local_trust_user?

    record.owner_id ? record.owner_id == current_user.id : current_user.admin?
  end

  # A before_action, after the one that sets @record.
  def authorize_modify!
    raise Forbidden, "only its owner can change this" unless can_modify?(@record)
  end
end
