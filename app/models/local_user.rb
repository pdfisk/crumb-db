# The stand-in for "whoever is at this machine" when a development server trusts
# local requests (see Authentication#local_trust?). It is not a database record:
# it has no id, so it owns nothing, but it may read and change everything.
class LocalUser
  include Singleton

  def id = nil
  def name = "local"
  def admin? = true

  def as_json(*)
    { "id" => nil, "name" => name, "admin" => true }
  end
end
