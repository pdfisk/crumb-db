# A FastBlips program: its source, the language it is written in, and its
# compiled code. Replaces BasicSource and PythonSource, which were one table
# per language.
#
# It was called App, and its table apps, before both were renamed.
class Script < ApplicationRecord
  include CompiledCodeAlias
  include Owned

  LANGUAGES = %w[basic python].freeze
  VISIBILITIES = %w[public unlisted private].freeze

  validates :name, presence: true
  # One script per name in a user's space. The shared space allows repeats, as
  # the tables it came from did.
  validates :name, uniqueness: { scope: :owner_id, message: "is already the name of one of this user's scripts" },
                   if: :owner_id?
  validates :language, inclusion: { in: LANGUAGES }
  validates :visibility, inclusion: { in: VISIBILITIES }
  validates :version, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :priority, numericality: { only_integer: true, in: 1..5 }
  validate :compiled_code_must_be_valid_json

  # Each change to the source is a new version, unless the save sets one.
  before_update :bump_version, if: :will_save_change_to_content?

  # The scripts this user may see in a listing: public ones and their own
  # (all of them, for an administrator). include_unlisted adds the unlisted
  # ones, for a request that names an owner and a script, since an unlisted
  # script is one you can only reach by its address.
  scope :listed_for, lambda { |user, include_unlisted: false|
    if user&.admin?
      all
    else
      found = where(visibility: include_unlisted ? %w[public unlisted] : %w[public])
      user ? found.or(where(owner_id: user.id)) : found
    end
  }

  # Whether this user may open the script by its address: anyone may open a
  # public or unlisted one; a private one is its owner's (shared-space ones,
  # administrators').
  def visible_to?(user)
    return true if visibility != "private"
    return false unless user

    user.admin? || owner_id == user.id
  end

  private

  def bump_version
    self.version += 1 unless will_save_change_to_version?
  end

  def compiled_code_must_be_valid_json
    return if compiled.blank?

    JSON.parse(compiled)
  rescue JSON::ParserError
    errors.add(:compiled, "must be a valid JSON string")
  end
end
