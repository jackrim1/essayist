class AddContentSimhashToEssays < ActiveRecord::Migration[8.1]
  def change
    add_column :essays, :content_simhash, :bigint
  end
end
