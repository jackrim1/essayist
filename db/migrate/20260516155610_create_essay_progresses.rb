class CreateEssayProgresses < ActiveRecord::Migration[8.1]
  def change
    create_table :essay_progresses do |t|
      t.references :user,  null: false, foreign_key: true, index: false
      t.references :essay, null: false, foreign_key: true, index: false
      t.decimal :last_read_position, precision: 10, scale: 8, default: "0.0", null: false
      t.integer :view_mode, default: 0, null: false
      t.timestamps
    end

    add_index :essay_progresses, [:user_id, :essay_id], unique: true
  end
end
