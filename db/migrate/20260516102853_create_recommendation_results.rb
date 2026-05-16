class CreateRecommendationResults < ActiveRecord::Migration[8.1]
  def change
    create_table :recommendation_results do |t|
      t.references :recommendation, null: false, foreign_key: true
      t.integer :position
      t.string :title
      t.string :author
      t.text :description
      t.string :url
      t.string :url_type
      t.string :search_query
      t.boolean :url_verified
      t.string :url_verification_note

      t.timestamps
    end
  end
end
