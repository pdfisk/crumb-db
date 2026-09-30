class PythonSource < ApplicationRecord
  include CompiledCodeAlias

  self.table_name = "python_source"

  validates :name, presence: true
  validates :priority, numericality: { only_integer: true, in: 1..5 }
  validate :compiled_code_must_be_valid_json

  private

  def compiled_code_must_be_valid_json
    return if compiled.blank?

    JSON.parse(compiled)
  rescue JSON::ParserError
    errors.add(:compiled, "must be a valid JSON string")
  end
end
