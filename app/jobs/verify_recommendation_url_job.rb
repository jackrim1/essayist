class VerifyRecommendationUrlJob < ApplicationJob
  queue_as :default

  def perform(result_id)
    result = RecommendationResult.find(result_id)
    return if result.url.blank?

    outcome = UrlVerificationService.call(result)
    result.update!(
      url_verified:           outcome[:verified],
      url_verification_note:  outcome[:note]
    )

    broadcast_result(result)
    maybe_complete(result.recommendation)
  rescue => e
    Rails.logger.error "VerifyRecommendationUrlJob failed for RecommendationResult##{result_id}: #{e.message}"
    result&.update!(url_verified: false, url_verification_note: "Error: #{e.message.first(200)}")
    broadcast_result(result) if result
    maybe_complete(result.recommendation) if result
  end

  private

  def broadcast_result(result)
    Turbo::StreamsChannel.broadcast_replace_to(
      result.recommendation.turbo_stream_name,
      target: "recommendation-result-#{result.id}",
      partial: "recommendations/result",
      locals: { result: result }
    )
  end

  def maybe_complete(recommendation)
    return if recommendation.results.where.not(url: nil).where(url_verified: nil).any?

    recommendation.update!(status: :complete)
    Turbo::StreamsChannel.broadcast_replace_to(
      recommendation.turbo_stream_name,
      target: "recommendation-content",
      partial: "recommendations/content",
      locals: { recommendation: recommendation }
    )
  end
end
