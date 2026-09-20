class PythonSource < ApplicationRecord
  self.table_name = "python_source"

  validates :name, presence: true
end
