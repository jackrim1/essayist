class CreateHighlights < ActiveRecord::Migration[8.0]
  def change
    create_table :highlights do |t|
      t.references :essay, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :content, null: false
      t.string :color, null: false, default: "yellow"
      # Anchor data for re-locating the highlight in the DOM on next load
      t.jsonb :anchor, null: false, default: {}
      t.text :note

      t.timestamps
    end

    add_index :highlights, [:essay_id, :created_at]
    add_index :highlights, :anchor, using: :gin
  end
end
