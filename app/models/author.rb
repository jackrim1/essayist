class Author < ApplicationRecord
  has_many :essays, dependent: :nullify

  validates :name, presence: true
  validates :name, uniqueness: { case_sensitive: false }

  def to_s = name
end
