# An account: the owner of apps. The name appears in addresses, so it is
# kept to letters, digits, "-" and "_".
class User < ApplicationRecord
  has_many :apps, foreign_key: :owner_id, inverse_of: :owner, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false },
                   format: { with: /\A[a-z0-9][a-z0-9_-]{1,29}\z/i,
                             message: "must be 2 to 30 letters, digits, - or _, starting with a letter or digit" }
  validates :email, uniqueness: { case_sensitive: false }, allow_nil: true,
                    format: { with: /\A[^@\s]+@[^@\s]+\z/ }

  before_validation { self.email = email.presence&.strip }
end
