# A project: a named, ordered list of scripts, with a description.
#
# Its scripts are kept in project_scripts, in order. They can be the owner's
# own, scripts that other users have shared, or ones in the shared space, and
# a script can be in any number of projects. Deleting a project, or a script,
# only takes it out of the lists.
#
# Each project_scripts row also holds a snapshot of its script - name,
# language, source, compiled code, priority and version - taken each time the
# project is saved, so the project keeps the scripts as they were then.
#
# "shared" is true when the owner has shared the project (false by default).
#
# In JSON a project has "scripts": [{ "id", "name", "language", "owner",
# "shared" }, ...] in order, and takes "script_ids": the scripts to be in it,
# in order, replacing the ones that were. as_json(snapshot: true) adds each
# script's snapshot ("content", "compiled_code", "priority", "version"; its
# "name" and "language" are those of the script when it was saved).
class Project < ApplicationRecord
  include Owned

  has_many :project_scripts, dependent: :delete_all, inverse_of: :project

  before_validation { self.name = name.to_s.strip }

  # One project per name in each user's space, and in the shared one.
  validates :name, presence: true, uniqueness: { scope: :owner_id }
  validates :shared, inclusion: { in: [true, false] }
  validate :script_ids_must_be_available

  after_save :store_scripts

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

  # The project's scripts, in order.
  def scripts
    Script.joins(:project_scripts).where(project_scripts: { project_id: id })
          .order("project_scripts.position", "project_scripts.id")
  end

  # The scripts that can be in the project: the owner's, the ones users have
  # shared and the ones in the shared space.
  def available_scripts
    found = Script.where(shared: true).or(Script.where(owner_id: nil))
    owner_id ? found.or(Script.where(owner_id: owner_id)) : found
  end

  # The scripts to be in the project once it is saved: these, in this order.
  def script_ids=(ids)
    @script_ids = Array(ids).map(&:to_i).uniq
  end

  def serializable_hash(options = nil)
    snapshots = project_scripts.index_by(&:script_id) if options && options[:snapshot]
    listed = scripts.includes(:owner).map do |s|
      entry = { "id" => s.id, "name" => s.name, "language" => s.language, "owner" => s.owner_name, "shared" => s.shared }
      entry.merge!(snapshots[s.id].snapshot_hash) if snapshots && snapshots[s.id]
      entry
    end
    super.merge("scripts" => listed)
  end

  private

  def script_ids_must_be_available
    return if @script_ids.blank?

    # A user made by this save has no scripts yet, so only shared ones fit.
    found = available_scripts.where(id: @script_ids).count
    errors.add(:scripts, "must be the owner's, shared by their owners or in the shared space") unless found == @script_ids.size
  end

  def store_scripts
    rows = ProjectScript.where(project_id: id)
    if @script_ids
      ids = @script_ids
      @script_ids = nil
      changed = rows.where.not(script_id: ids).delete_all.positive?
      have = rows.pluck(:script_id, :id, :position).to_h { |script_id, row, position| [script_id, [row, position]] }
      ids.each_with_index do |script_id, position|
        row, was = have[script_id]
        if row.nil?
          ProjectScript.create!(project_id: id, script_id: script_id, position: position)
          changed = true
        elsif was != position
          ProjectScript.where(id: row).update_all(position: position)
          changed = true
        end
      end
      touch if changed && !saved_changes?   # a new list is a change, for sync to see
    elsif saved_change_to_owner_id?
      # Moved to another space: scripts its new owner cannot use drop out.
      rows.where.not(script_id: available_scripts.select(:id)).delete_all
    end
    snapshot_scripts
  end

  # Takes a fresh snapshot of every script in the project.
  def snapshot_scripts
    project_scripts.reset
    ProjectScript.where(project_id: id).includes(:script).find_each { |row| row.snapshot! }
  end
end
