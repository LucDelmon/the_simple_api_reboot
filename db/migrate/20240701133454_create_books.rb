class CreateBooks < ActiveRecord::Migration[7.1]
  def change
    create_table :books do |t|
      t.string :title, null: false
      t.integer :page_count, null: false
      t.belongs_to :author, index: true, foreign_key: true

      t.timestamps
    end
  end
end
