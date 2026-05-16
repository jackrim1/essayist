class CreateRecommendations < ActiveRecord::Migration[8.1]
  def change
    create_table :recommendations do |t|
      t.references :essay, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :kind
      t.integer :status
      t.text :error_message

      t.timestamps
    end
  end
end
