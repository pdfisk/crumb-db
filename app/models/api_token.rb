# A sign-in token: what a client sends as "Authorization: Bearer <token>".
#
# The token itself is shown once, when it is issued; the table keeps only its
# SHA-256 digest. (A token is 256 random bits, so a fast digest is enough: there
# is nothing to guess, unlike a password.)
class ApiToken < ApplicationRecord
  LIFETIME = 30.days

  belongs_to :user

  scope :live, -> { where("expires_at > ?", Time.current) }

  def self.digest(token)
    Digest::SHA256.hexdigest(token.to_s)
  end

  # Makes a token for the user. Returns the record and the token itself.
  def self.issue(user)
    where("expires_at <= ?", Time.current).delete_all   # tidy up as we go
    token = SecureRandom.urlsafe_base64(32)
    record = create!(user: user, token_digest: digest(token), expires_at: LIFETIME.from_now)
    [ record, token ]
  end

  # The live record for a token as a client sent it, or nil.
  def self.find_live(token)
    return nil if token.blank?

    live.includes(:user).find_by(token_digest: digest(token))
  end
end
