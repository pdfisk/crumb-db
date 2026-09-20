class CreatePythonSource < ActiveRecord::Migration[8.0]
  def change
    # if_not_exists: safe to run against a database that already has the table
    create_table :python_source, if_not_exists: true do |t|
      t.string :name
      t.text :content

      t.timestamps
    end
    add_index :python_source, :name, if_not_exists: true
  end
end
