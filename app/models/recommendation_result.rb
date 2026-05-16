class RecommendationResult < ApplicationRecord
  belongs_to :recommendation

  validates :title,       presence: true
  validates :author,      presence: true
  validates :description, presence: true
  validates :position,    presence: true, numericality: { only_integer: true, greater_than: 0 }

  def search_url
    query = search_query.presence || "\"#{title}\" by #{author} essay"
    "https://www.google.com/search?q=#{CGI.escape(query)}"
  end

  def importable?
    url.present? && url_verified == true
  end

  def verification_pending?
    url.present? && url_verified.nil?
  end
end
