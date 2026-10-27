# A project: a named, ordered list of scripts, with a description.
#
# The scripts are kept in the project's own record, as `scripts`: a JSON list
# of "<owner>/<name>" strings, in order ("peter/snake"; an empty owner, "/snake",
# is a script in the shared space). There are no foreign keys: a script can be
# in any number of projects, and deleting or renaming a script leaves its name
# in the lists that have it, for the client to report as missing.
#
# A project can list only the owner's scripts and those in the shared space.
#
# "shared" is true when the owner has shared the project (false by default).
class Project < ApplicationRecord
  include Owned

  # Kept as JSON text in a text column ("[]" by default).
  serialize :scripts, type: Array, coder: JSON

  before_validation { self.name = name.to_s.strip }
  before_validation :clean_scripts

  # One project per name in each user's space, and in the shared one.
  validates :name, presence: true, uniqueness: { scope: :owner_id }
  validates :shared, inclusion: { in: [true, false] }
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

  # "owner/name" -> ["owner", "name"], or nil if it is not one. The owner may be empty.
  def self.split_ref(ref)
    owner, name = ref.to_s.split("/", 2)
    name.to_s.strip.empty? ? nil : [ owner.to_s.strip, name.to_s.strip ]
  end

  private

  # A list of strings, without repeats: anything else is left for the validation to refuse.
  def clean_scripts
    return unless scripts.is_a?(Array) && scripts.all?(String)

    self.scripts = scripts.map(&:strip).uniq
  end

  def scripts_must_be_usable
    unless scripts.is_a?(Array) && scripts.all?(String)
      errors.add(:scripts, "must be a list of \"owner/name\" strings")
      return
    end
    mine = owner_name.to_s.downcase
    scripts.each do |ref|
      owner, name = self.class.split_ref(ref)
      if name.nil?
        errors.add(:scripts, "#{ref.inspect} is not an \"owner/name\"")
      elsif !owner.empty? && owner.downcase != mine
        errors.add(:scripts, "#{ref.inspect} is not the owner's or in the shared space")
      end
    end
  end
end
