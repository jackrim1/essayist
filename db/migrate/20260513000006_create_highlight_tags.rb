class CreateHighlightTags < ActiveRecord::Migration[8.0]
  def change
    create_table :highlight_tags do |t|
      t.references :highlight, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end

    add_index :highlight_tags, [:highlight_id, :tag_id], unique: true
  end
end
