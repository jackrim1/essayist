class MakeAuthorsGlobal < ActiveRecord::Migration[8.1]
  def up
    # Deduplicate: for each normalised name keep the lowest id
    execute <<~SQL
      UPDATE essays
      SET author_id = survivors.min_id
      FROM (
        SELECT lower(name) AS norm, min(id) AS min_id
        FROM authors
        GROUP BY lower(name)
      ) survivors
      JOIN authors a ON lower(a.name) = survivors.norm
      WHERE essays.author_id = a.id AND a.id != survivors.min_id
    SQL

    execute <<~SQL
      DELETE FROM authors
      WHERE id NOT IN (
        SELECT min(id) FROM authors GROUP BY lower(name)
      )
    SQL

    remove_index  :authors, [:user_id, :name]
    remove_index  :authors, :user_id
    remove_column :authors, :user_id

    add_index :authors, "lower(name)", unique: true, name: "index_authors_on_lower_name"
  end

  def down
    remove_index  :authors, name: "index_authors_on_lower_name"
    add_column    :authors, :user_id, :bigint, null: false, default: 0
    add_index     :authors, [:user_id, :name], unique: true
    add_index     :authors, :user_id
  end
end
