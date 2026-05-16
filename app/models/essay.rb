class Essay < ApplicationRecord
  belongs_to :author, optional: true
  belongs_to :uploaded_by, class_name: "User", foreign_key: :uploaded_by_id, optional: true

  has_many :highlights,       dependent: :destroy
  has_many :recommendations,  dependent: :destroy
  has_many :essay_progresses, dependent: :destroy
  has_one_attached :original_file

  validates :title, presence: true, unless: -> { source_url.present? }
  validates :source_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true

  before_save :refresh_simhash, if: :content_changed?

  scope :recent, -> { order(updated_at: :desc) }
  scope :search_by, ->(q) {
    safe_q = sanitize_sql_like(q)
    where("title ILIKE :prefix OR author_name ILIKE :prefix OR title % :q", prefix: "%#{safe_q}%", q: q)
      .order(Arel.sql("similarity(title, #{connection.quote(q)}) DESC"))
  }

  def potential_duplicates
    by_title   = title.present?            ? title_matches   : []
    by_content = content_simhash.present?  ? content_matches : []
    ids = (by_title + by_content).uniq
    ids.any? ? Essay.where(id: ids).where.not(id: id) : Essay.none
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
    Essay.where.not(id: id)
         .where("lower(regexp_replace(title, '[^a-z0-9 ]', ' ', 'g')) = ?", normalized)
         .pluck(:id)
  end

  def content_matches
    Essay.where.not(id: id).where.not(content_simhash: nil)
         .pluck(:id, :content_simhash)
         .filter_map { |eid, hash| eid if DuplicateDetector.similar?(content_simhash, hash) }
  end
end
