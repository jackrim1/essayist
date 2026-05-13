class Tag < ApplicationRecord
  belongs_to :user
  has_many   :highlight_tags, dependent: :destroy
  has_many   :highlights, through: :highlight_tags

  validates :name, presence: true, uniqueness: { scope: :user_id }
  before_save { self.name = name.strip.downcase }
end
