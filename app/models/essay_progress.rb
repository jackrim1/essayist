class EssayProgress < ApplicationRecord
  belongs_to :user
  belongs_to :essay

  enum :view_mode, { infinite: 0, paged: 1 }

  validates :last_read_position, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }

  def reading_percent
    (last_read_position * 100).round
  end
end
