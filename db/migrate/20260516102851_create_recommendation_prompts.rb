class CreateRecommendationPrompts < ActiveRecord::Migration[8.1]
  def change
    create_table :recommendation_prompts do |t|
      t.string :kind
      t.text :body

      t.timestamps
    end
  end
end
