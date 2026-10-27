# These tables belong to the COBOL studio that used to share this database and
# nothing in FastBlips reads them. Dropping them deletes their rows for good.
class DropUnusedTables < ActiveRecord::Migration[8.0]
  TABLES = %w[cobol_models cobol_source_files data_models jcl_models jcl_source_files].freeze

  def up
    TABLES.each { |table| drop_table table, if_exists: true }
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "the rows of #{TABLES.join(', ')} are gone"
  end
end
