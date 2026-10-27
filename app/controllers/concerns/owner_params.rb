# The owner in requests, for controllers of Owned records.
#
#   ?owner=peter   the records in that user's space
#   ?owner=        the records in the shared space (no owner)
#   no owner       every record the caller may see
#
# In a body, "owner": "peter" puts the record in that user's space and
# "owner": "" in the shared one. Only the signed-in user's own name is allowed
# (and "" for an administrator); a body with no owner puts a new record in the
# signed-in user's space. Needs Authentication (require_login! first).
module OwnerParams
  private

  def in_space(records)
    records = records.includes(:owner)
    params.key?(:owner) ? records.owned_by(params[:owner]) : records
  end

  # Moves a body's "owner" (a user name) into attrs as owner_name, after
  # checking that the caller may put records there.
  def with_owner(attrs, body)
    if body.key?(:owner)
      name = body[:owner].to_s.strip
      allowed = name.empty? ? current_user.admin? : name.casecmp?(current_user.name)
      allowed ||= local_trust_user?
      raise Authentication::Forbidden, "you can only put records in your own space" unless allowed

      attrs[:owner_name] = name
      ensure_local_owner(name) if local_trust_user?
    elsif action_name == "create"
      attrs[:owner_name] = local_trust_user? ? "" : current_user.name
    end
    attrs
  end

  # On a locally trusted server a space for a new name is made on first use, as
  # it was before sign-in existed. Its password is random: set one with
  # bin/rails "users:set_password[name]" if you ever want to sign in as it.
  def ensure_local_owner(name)
    return if name.empty? || User.exists?(["lower(name) = ?", name.downcase])

    User.create(name: name, password: SecureRandom.hex(16))
  end
end
