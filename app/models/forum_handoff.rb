# A one-time code that signs an IDE user in to the forum.
#
# The IDE (signed in with a bearer token) asks the API for a code
# (POST /forum_handoff) and opens https://forum.fastblips.com/sso?code=...;
# the forum redeems the code and starts its own cookie session. A code works
# once, for LIFETIME, and the table keeps only its SHA-256 digest (as ApiToken
# does), so a database copy holds no usable codes.
class ForumHandoff < ApplicationRecord
  LIFETIME = 60.seconds

  belongs_to :user

  def self.digest(code)
    Digest::SHA256.hexdigest(code.to_s)
  end

  # Makes a code for the user. Returns the record and the code itself.
  def self.issue(user)
    where("expires_at <= ?", 1.hour.ago).delete_all   # tidy up as we go
    code = SecureRandom.urlsafe_base64(32)
    record = create!(user: user, code_digest: digest(code), expires_at: LIFETIME.from_now)
    [ record, code ]
  end

  # The user the code was issued to, if it is known, unused and not expired;
  # else nil. Marking it used is one UPDATE, so two requests racing with the
  # same code cannot both succeed.
  def self.redeem(code)
    return nil if code.blank?

    now = Time.current
    scope = where(code_digest: digest(code), used_at: nil).where("expires_at > ?", now)
    record = scope.first
    return nil unless record
    return nil unless scope.where(id: record.id).update_all(used_at: now, updated_at: now) == 1

    record.user
  end

  # path if it is a path on the same site, else nil. "//host" and "/\\host"
  # are refused: browsers treat them as other sites.
  def self.local_path(path)
    path = path.to_s
    path.start_with?("/") && !path.start_with?("//", "/\\") ? path : nil
  end
end
