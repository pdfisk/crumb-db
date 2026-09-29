class AddPriorityAndCompiledCodeToSources < ActiveRecord::Migration[8.0]
  TABLES = %i[basic_source python_source].freeze

  def change
    TABLES.each do |table|
      add_column table, :priority, :integer, null: false, default: 3
      add_column table, :compiled, :text
      add_check_constraint table, "priority BETWEEN 1 AND 5", name: "#{table}_priority_range"
    end
  end
end
