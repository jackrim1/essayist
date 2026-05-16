class RenameAuthorOnEssays < ActiveRecord::Migration[8.1]
  def change
    rename_column :essays, :author, :author_name
  end
end
