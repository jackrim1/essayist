class Essay < ApplicationRecord
  belongs_to :user
  has_many   :highlights, dependent: :destroy
  has_one_attached :original_file

  enum :view_mode, { infinite: 0, paged: 1 }

  validates :title, presence: true
  validates :last_read_position, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }

  scope :recent, -> { order(updated_at: :desc) }

  # After upload, kick off text extraction as a background job
  after_create_commit :extract_text_later, if: -> { original_file.attached? }

  def reading_percent
    (last_read_position * 100).round
  end

  def estimated_minutes
    return nil if word_count.nil?
    (word_count / 200.0).ceil
  end

  private

  def extract_text_later
    ExtractEssayTextJob.perform_later(id)
  end
end
