# A project: a named, ordered list of scripts, with a description.
#
# The scripts are kept in the project's own record, as `scripts`: a JSON list
# of the scripts themselves, in order, each
#
#   { "name" => "Ball", "language" => "python", "content" => "print(1)",
#     "priority" => 3, "compiled_code" => "{...}" }
#
# where priority and compiled_code may be left out. Each is the project's own
# copy of a script's source: adding a script to a project copies it in, and
# changing it in the project leaves any record in the scripts table as it was
# (and the other way round). Names are unique within a project, ignoring case.
#
# "shared" is true when the owner has shared the project (false by default).
# "category" says what kind of project it is (CATEGORIES; development by
# default): the mobile start page lists the shared mobile-game projects.
class Project < ApplicationRecord
  include Owned

  CATEGORIES = %w[development desktop-game desktop-app mobile-game mobile-app].freeze

  # The fields a project's script may have; anything else is dropped.
  SCRIPT_FIELDS = %w[name language content priority compiled_code].freeze

  # The scripts column: JSON text, read as a list. An empty list is written as
  # "[]". (`serialize ..., type: Array` writes it as NULL, since it treats the
  # empty list as its default, and the column is NOT NULL.) A value that is
  # not a list is kept as it is, for the validation to refuse.
  class ScriptList < ActiveRecord::Type::Value
    def type = :text

    def deserialize(value)
      return [] if value.nil?

      value.is_a?(String) ? (JSON.parse(value) rescue []) : value
    end

    def serialize(value)
      (value.nil? ? [] : value).to_json
    end

    def changed_in_place?(raw_old_value, new_value)
      deserialize(raw_old_value) != new_value
    end
  end

  attribute :scripts, ScriptList.new, default: -> { [] }

  before_validation { self.name = name.to_s.strip }
  before_validation :clean_scripts

  # One project per name in each user's space, and in the shared one.
  validates :name, presence: true, uniqueness: { scope: :owner_id }
  validates :shared, inclusion: { in: [true, false] }
  validates :category, inclusion: { in: CATEGORIES }
  validate :scripts_must_be_usable

  # The projects this user may see: shared ones, ones in the shared space and
  # their own (all of them, for an administrator).
  scope :visible_to, lambda { |user|
    if user&.admin?
      all
    else
      found = where(shared: true).or(where(owner_id: nil))
      user ? found.or(where(owner_id: user.id)) : found
    end
  }

  def visible_to?(user)
    shared? || owner_id.nil? || (!user.nil? && (owner_id == user.id || user.admin?))
  end

  # A project's copy of a script record: the fields a project keeps.
  def self.script_copy(script)
    copy = { "name" => script.name, "language" => script.language, "content" => script.content.to_s }
    copy["priority"] = script.priority unless script.priority.nil?
    copy["compiled_code"] = script.compiled unless script.compiled.blank?
    copy
  end

  private

  # Hashes with string keys, only the known fields, the name trimmed, an empty
  # source for none: anything else is left for the validation to refuse.
  def clean_scripts
    return unless scripts.is_a?(Array) && scripts.all? { |s| s.is_a?(Hash) }

    self.scripts = scripts.map do |s|
      s = s.to_h.transform_keys(&:to_s).slice(*SCRIPT_FIELDS)
      s["name"] = s["name"].to_s.strip
      s["content"] = s["content"].to_s
      s.delete("priority") if s["priority"].nil? || s["priority"] == ""
      s.delete("compiled_code") if s["compiled_code"].blank?
      s["priority"] = Integer(s["priority"], exception: false) || s["priority"] if s.key?("priority")
      s
    end
  end

  def scripts_must_be_usable
    unless scripts.is_a?(Array) && scripts.all? { |s| s.is_a?(Hash) }
      errors.add(:scripts, "must be a list of scripts, each with a name, a language and its source")
      return
    end
    seen = {}
    scripts.each_with_index do |s, i|
      label = s["name"].to_s.empty? ? "script #{i + 1}" : s["name"].inspect
      errors.add(:scripts, "#{label} has no name") if s["name"].to_s.empty?
      unless Script::LANGUAGES.include?(s["language"])
        errors.add(:scripts, "#{label} has no known language (#{Script::LANGUAGES.join(', ')})")
      end
      if s.key?("priority") && !(s["priority"].is_a?(Integer) && (1..5).cover?(s["priority"]))
        errors.add(:scripts, "#{label} has a priority that is not a whole number from 1 to 5")
      end
      if s.key?("compiled_code")
        begin
          JSON.parse(s["compiled_code"].to_s)
        rescue JSON::ParserError
          errors.add(:scripts, "#{label} has compiled code that is not valid JSON")
        end
      end
      key = s["name"].to_s.downcase
      next if key.empty?

      errors.add(:scripts, "#{label} is in the project twice") if seen[key]
      seen[key] = true
    end
  end
end
