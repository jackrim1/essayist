class Tag < ApplicationRecord
  belongs_to :user
  has_many   :highlight_tags, dependent: :destroy
  has_many   :highlights, through: :highlight_tags

  validates :name, presence: true,
                   uniqueness: { scope: :user_id },
                   format: { with: /\A[a-z0-9-]+\z/, message: "only letters, numbers, and hyphens" }
  before_save { self.name = name.strip.downcase }

  def self.format_count(n)
    n = n.to_i
    if    n >= 10_000 then "10k+"
    elsif n >= 1_000  then "#{(n / 1000.0).round}k"
    else n.to_s
    end
  end
end
