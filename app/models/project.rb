# A project: a named group of scripts in one space, with a description.
#
# Its scripts are the scripts in the same space (the same owner, or none)
# whose project_name is the project's name, so a script is in at most one
# project. Renaming a project takes its scripts with it; deleting one leaves
# them, in no project.
#
# In JSON a project has "scripts": [{ "id", "name", "language" }, ...], and
# takes "script_ids": the scripts to be in it, replacing the ones that were.
class Project < ApplicationRecord
  include Owned

  before_validation { self.name = name.to_s.strip }

  # One project per name in each user's space, and in the shared one.
  validates :name, presence: true, uniqueness: { scope: :owner_id }
  validate :script_ids_must_be_in_the_space

  after_update :keep_scripts
  after_save :take_scripts
  before_destroy :release_scripts

  def scripts
    Script.where(owner_id: owner_id, project_name: name)
  end

  # The scripts to be in the project once it is saved: these and no others.
  def script_ids=(ids)
    @script_ids = Array(ids).map(&:to_i).uniq
  end

  def serializable_hash(options = nil)
    listed = scripts.order(:name, :id).pluck(:id, :name, :language)
    super.merge("scripts" => listed.map { |id, name, language| { "id" => id, "name" => name, "language" => language } })
  end

  private

  def script_ids_must_be_in_the_space
    return if @script_ids.blank?

    # A user made by this save has no scripts yet.
    found = owner&.new_record? ? 0 : Script.where(owner_id: owner_id, id: @script_ids).count
    errors.add(:scripts, "must all be in the project's space") unless found == @script_ids.size
  end

  # A renamed project keeps its scripts. One moved to another space does
  # not: scripts stay with their owner, in no project.
  def keep_scripts
    was = Script.where(owner_id: owner_id_before_last_save, project_name: name_before_last_save)
    if saved_change_to_owner_id?
      was.update_all(project_name: nil)
    elsif saved_change_to_name?
      was.update_all(project_name: name)
    end
  end

  def take_scripts
    return if @script_ids.nil?

    scripts.where.not(id: @script_ids).update_all(project_name: nil)
    Script.where(owner_id: owner_id, id: @script_ids).update_all(project_name: name)
    @script_ids = nil
  end

  def release_scripts
    scripts.update_all(project_name: nil)
  end
end
