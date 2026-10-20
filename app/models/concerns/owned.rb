# A record that belongs to a user's namespace. With no owner it is in the
# shared space, where everything was before there were users.
#
# In JSON the owner is the user's name: records are returned with
# "owner": "peter" (null when shared), and owner_name= takes one. A name that
# is not a registered user makes the record invalid; it no longer makes the user.
module Owned
  extend ActiveSupport::Concern

  included do
    belongs_to :owner, class_name: "User", optional: true

    validate { errors.add(:owner, "#{@unknown_owner} is not a registered user") if @unknown_owner }

    # The records in a user's space; a blank name is the shared space.
    scope :owned_by, lambda { |name|
      name = name.to_s.strip
      if name.empty?
        where(owner_id: nil)
      else
        where(owner_id: User.where("lower(name) = ?", name.downcase).select(:id))
      end
    }
  end

  def owner_name
    owner&.name
  end

  def owner_name=(name)
    name = name.to_s.strip
    @unknown_owner = nil
    if name.empty?
      self.owner = nil
    elsif (user = User.find_by("lower(name) = ?", name.downcase))
      self.owner = user
    else
      @unknown_owner = name
    end
  end

  def serializable_hash(options = nil)
    super.merge("owner" => owner_name)
  end
end
