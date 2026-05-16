class Author < ApplicationRecord
  belongs_to :user
  has_many   :essays, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :user_id, case_sensitive: false }

  def to_s
    name
  end
end
