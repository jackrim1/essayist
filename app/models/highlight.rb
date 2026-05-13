class Highlight < ApplicationRecord
  belongs_to :essay
  belongs_to :user
  has_many   :highlight_tags, dependent: :destroy
  has_many   :tags, through: :highlight_tags

  COLORS = %w[yellow green blue pink purple].freeze

  validates :content, presence: true
  validates :color,   inclusion: { in: COLORS }

  scope :for_essay, ->(essay) { where(essay: essay).order(:created_at) }
end
