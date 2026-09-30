# The crumb client names the compiled-code field compiled_code; the column is
# compiled. Accept either name when saving, and send both in JSON, so the
# client's Compile button stores its code and a loaded record carries it.
module CompiledCodeAlias
  extend ActiveSupport::Concern

  included do
    alias_attribute :compiled_code, :compiled
  end

  def serializable_hash(options = nil)
    hash = super
    hash["compiled_code"] = hash["compiled"] if hash.key?("compiled")
    hash
  end
end
