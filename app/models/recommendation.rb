class Recommendation < ApplicationRecord
  belongs_to :essay
  belongs_to :user
  has_many   :results, class_name: "RecommendationResult", dependent: :destroy

  KINDS = %w[author subject].freeze

  enum :status, { pending: 0, generating: 1, verifying: 2, complete: 3, failed: 4 }

  validates :kind,   presence: true, inclusion: { in: KINDS }
  validates :status, presence: true

  def turbo_stream_name
    "recommendation_#{id}"
  end
end
