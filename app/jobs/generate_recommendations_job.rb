class GenerateRecommendationsJob < ApplicationJob
  queue_as :default

  def perform(recommendation_id)
    recommendation = Recommendation.find(recommendation_id)
    recommendation.update!(status: :generating)

    raw_results = RecommendationService.call(recommendation)
    owned_keys  = library_keys(recommendation.user)
    filtered    = raw_results.reject { |data| already_owned?(data, owned_keys) }

    position = 0
    recommendation.transaction do
      recommendation.results.destroy_all
      filtered.each do |data|
        position += 1
        recommendation.results.create!(
          position:    position,
          title:       data["title"].to_s.strip,
          author:      data["author"].to_s.strip,
          description: data["description"].to_s.strip,
          url:         data["url"].presence,
          url_type:    data["url_type"].presence
        )
      end
    end

    recommendation.update!(status: :verifying)
    broadcast_results(recommendation)

    url_results = recommendation.results.where.not(url: nil)
    if url_results.any?
      url_results.each { |r| VerifyRecommendationUrlJob.perform_later(r.id) }
    else
      recommendation.update!(status: :complete)
      broadcast_results(recommendation)
    end
  rescue => e
    recommendation&.update!(status: :failed, error_message: e.message)
    broadcast_results(recommendation) rescue nil
    Rails.logger.error "GenerateRecommendationsJob failed for Recommendation##{recommendation_id}: #{e.message}"
  end

  private

  # Returns a Set of normalised "title author" keys for every essay in the global library.
  def library_keys(_user = nil)
    Essay.pluck(:title, :author_name).map do |title, author|
      normalise("#{title} #{author}")
    end.to_set
  end

  # True if the recommendation's title+author fuzzy-matches any owned essay.
  # Strategy: normalise both sides, then check word overlap.
  # A result is "owned" if >= 70% of its significant words (3+ chars) appear
  # in an owned essay's normalised title+author string, and at least 2 words match.
  def already_owned?(data, owned_keys)
    candidate = normalise("#{data["title"]} #{data["author"]}")
    words     = significant_words(candidate)
    return false if words.empty?

    owned_keys.any? do |owned|
      matches = words.count { |w| owned.include?(w) }
      matches >= 2 && matches.to_f / words.size >= 0.7
    end
  end

  def normalise(str)
    str.to_s.downcase.gsub(/[^a-z0-9\s]/, " ").squish
  end

  def significant_words(str)
    str.split.select { |w| w.length >= 3 }
  end

  def broadcast_results(recommendation)
    Turbo::StreamsChannel.broadcast_replace_to(
      recommendation.turbo_stream_name,
      target: "recommendation-content",
      partial: "recommendations/content",
      locals: { recommendation: recommendation }
    )
  end
end
