# An account: the owner of scripts, screens and projects. The name appears
# in addresses, so it is kept to letters, digits, "-" and "_".
#
# A password is required to register (8 to 72 characters: bcrypt reads no more
# than 72 bytes). Users from before sign-in have no password digest and cannot
# sign in until bin/rails "users:set_password[name]" gives them one.
class User < ApplicationRecord
  has_secure_password

  has_many :api_tokens, dependent: :delete_all
  has_many :scripts, foreign_key: :owner_id, inverse_of: :owner, dependent: :restrict_with_error
  has_many :viewports, foreign_key: :owner_id, inverse_of: :owner, dependent: :restrict_with_error
  has_many :projects, foreign_key: :owner_id, inverse_of: :owner, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false },
                   format: { with: /\A[a-z0-9][a-z0-9_-]{1,29}\z/i,
                             message: "must be 2 to 30 letters, digits, - or _, starting with a letter or digit" }
  validates :email, uniqueness: { case_sensitive: false }, allow_nil: true,
                    format: { with: /\A[^@\s]+@[^@\s]+\z/ }
  validates :password, length: { minimum: 8 }, allow_nil: true

  before_validation { self.email = email.presence&.strip }

  # The user who signed in with this name and password, or nil. The same work
  # is done whether or not the name exists, so the time taken does not say.
  def self.authenticate(name, password)
    user = find_by("lower(name) = ?", name.to_s.downcase)
    if user&.password_digest.present?
      user.authenticate(password.to_s) || nil
    else
      BCrypt::Password.new(dummy_digest).is_password?(password.to_s)
      nil
    end
  end

  def self.dummy_digest
    cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
    @dummy_digest ||= BCrypt::Password.create("not a password", cost: cost).to_s
  end

  # Administrators (the ADMIN_USERS config var, comma-separated names) may also
  # change records in the shared space.
  def admin?
    ENV.fetch("ADMIN_USERS", "").split(",").map { |n| n.strip.downcase }.include?(name.downcase)
  end
end
