class Essay < ApplicationRecord
  belongs_to :user
  has_many   :highlights,      dependent: :destroy
  has_many   :recommendations, dependent: :destroy
  has_one_attached :original_file

  enum :view_mode, { infinite: 0, paged: 1 }

  validates :title, presence: true, unless: -> { source_url.present? }
  validates :last_read_position, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }
  validates :source_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid http/https URL" }, allow_blank: true

  before_save :refresh_simhash, if: :content_changed?

  scope :recent, -> { order(updated_at: :desc) }

  def potential_duplicates
    by_title    = title.present?         ? title_matches    : []
    by_content  = content_simhash.present? ? content_matches : []
    ids = (by_title + by_content).uniq
    ids.any? ? user.essays.where(id: ids) : self.class.none
  end

  def reading_percent
    (last_read_position * 100).round
  end

  def estimated_minutes
    return nil if word_count.nil?
    (word_count / 200.0).ceil
  end

  private

  def refresh_simhash
    self.content_simhash = DuplicateDetector.simhash(content)
  end

  def title_matches
    normalized = title.downcase.gsub(/[^a-z0-9\s]/, " ").squish
    user.essays.where.not(id: id)
        .where("lower(regexp_replace(title, '[^a-z0-9 ]', ' ', 'g')) = ?", normalized)
        .pluck(:id)
  end

  def content_matches
    user.essays.where.not(id: id).where.not(content_simhash: nil)
        .pluck(:id, :content_simhash)
        .filter_map { |id, hash| id if DuplicateDetector.similar?(content_simhash, hash) }
  end

end
