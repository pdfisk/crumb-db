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
  validates :shared, inclusion: { in: [true, false] }
  validate :compiled_code_must_be_valid_json

  # Each change to the source is a new version, unless the save sets one.
  before_update :bump_version, if: :will_save_change_to_content?

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
