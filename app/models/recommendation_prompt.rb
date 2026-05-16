class RecommendationPrompt < ApplicationRecord
  KINDS = %w[author subject].freeze

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :body, presence: true

  def self.for(kind)
    find_by!(kind: kind.to_s)
  end

  # Interpolate {{title}}, {{author}}, {{content_excerpt}} placeholders.
  def render(title:, author:, content_excerpt: "")
    body
      .gsub("{{title}}", title.to_s)
      .gsub("{{author}}", author.to_s)
      .gsub("{{content_excerpt}}", content_excerpt.to_s)
  end
end
