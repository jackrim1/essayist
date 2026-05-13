class CreateEssays < ActiveRecord::Migration[8.0]
  def change
    create_table :essays do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.string :author
      t.text :content          # extracted plain text, stored as HTML paragraphs
      t.decimal :last_read_position, precision: 10, scale: 8, default: 0.0
      t.integer :view_mode, default: 0, null: false  # 0=infinite, 1=paged
      t.integer :word_count
      t.string :original_filename

      t.timestamps
    end

    add_index :essays, [:user_id, :updated_at]
  end
end
