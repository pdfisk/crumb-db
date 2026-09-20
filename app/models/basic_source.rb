class BasicSource < ApplicationRecord
  self.table_name = "basic_source"

  validates :name, presence: true
end
