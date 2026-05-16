class AddAuthorIdToEssays < ActiveRecord::Migration[8.1]
  def change
    add_reference :essays, :author, null: true, foreign_key: true
  end
end
