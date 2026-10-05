# The owner in requests, for controllers of Owned records.
#
#   ?owner=peter   the records in that user's space
#   ?owner=        the records in the shared space (no owner)
#   no owner       every record
#
# In a body, "owner": "peter" puts the record in that user's space and
# "owner": "" in the shared one.
module OwnerParams
  private

  def in_space(records)
    records = records.includes(:owner)
    params.key?(:owner) ? records.owned_by(params[:owner]) : records
  end

  # Moves a body's "owner" (a user name) into attrs as owner_name.
  def with_owner(attrs, body)
    attrs[:owner_name] = body[:owner] if body.key?(:owner)
    attrs
  end
end
