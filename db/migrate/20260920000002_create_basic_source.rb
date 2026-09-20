class CreateBasicSource < ActiveRecord::Migration[8.0]
  def change
    create_table :basic_source, if_not_exists: true do |t|
      t.string :name
      t.text :content

      t.timestamps
    end
    add_index :basic_source, :name, if_not_exists: true
  end
end
