class Essay < ApplicationRecord
  belongs_to :user
  has_many   :highlights, dependent: :destroy
  has_one_attached :original_file

  enum :view_mode, { infinite: 0, paged: 1 }

  validates :title, presence: true, unless: -> { source_url.present? }
  validates :last_read_position, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :source_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid http/https URL" }, allow_blank: true

  scope :recent, -> { order(updated_at: :desc) }

  def reading_percent
    (last_read_position * 100).round
  end

  def estimated_minutes
    return nil if word_count.nil?
    (word_count / 200.0).ceil
  end

end
