# A record that belongs to a user's namespace. With no owner it is in the
# shared space, where everything was before there were users.
#
# In JSON the owner is the user's name: records are returned with
# "owner": "peter" (null when shared), and owner_name= takes one.
module Owned
  extend ActiveSupport::Concern

  included do
    belongs_to :owner, class_name: "User", optional: true

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

  # Until there is sign-in, naming a user who does not exist creates them
  # when the record is saved.
  def owner_name=(name)
    name = name.to_s.strip
    self.owner = name.empty? ? nil : (User.find_by("lower(name) = ?", name.downcase) || User.new(name: name))
  end

  def serializable_hash(options = nil)
    super.merge("owner" => owner_name)
  end
end
