class AddSourceUrlToEssays < ActiveRecord::Migration[8.1]
  def change
    add_column :essays, :source_url, :string
  end
end
