class MakeEssaysGlobal < ActiveRecord::Migration[8.1]
  def up
    # Backfill essay_progresses from existing per-user reading positions
    execute <<~SQL
      INSERT INTO essay_progresses (user_id, essay_id, last_read_position, view_mode, created_at, updated_at)
      SELECT user_id, id, last_read_position, view_mode, NOW(), NOW()
      FROM essays
      WHERE last_read_position > 0 OR view_mode != 0
      ON CONFLICT (user_id, essay_id) DO NOTHING
    SQL

    # Lift user_id to uploaded_by_id (optional attribution)
    add_column :essays, :uploaded_by_id, :bigint
    add_foreign_key :essays, :users, column: :uploaded_by_id

    execute "UPDATE essays SET uploaded_by_id = user_id"

    remove_index  :essays, [:user_id, :updated_at]
    remove_column :essays, :user_id
    remove_column :essays, :last_read_position
    remove_column :essays, :view_mode

    add_column :essays, :published_year, :integer

    # Enable trigram extension for fuzzy title search
    enable_extension "pg_trgm"
    add_index :essays, :title, using: :gin, opclass: :gin_trgm_ops
  end

  def down
    remove_index  :essays, :title
    disable_extension "pg_trgm"
    remove_column :essays, :published_year
    remove_foreign_key :essays, column: :uploaded_by_id
    remove_column :essays, :uploaded_by_id

    add_column    :essays, :view_mode,           :integer, default: 0, null: false
    add_column    :essays, :last_read_position,  :decimal, precision: 10, scale: 8, default: "0.0", null: false
    add_reference :essays, :user, null: false, foreign_key: true
    add_index     :essays, [:user_id, :updated_at]
  end
end
