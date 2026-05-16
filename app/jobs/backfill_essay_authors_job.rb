class BackfillEssayAuthorsJob < ApplicationJob
  queue_as :default

  def perform
    scope = Essay.where.not(author: [nil, ""]).where(author_id: nil)
    count = scope.count
    Rails.logger.info "BackfillEssayAuthorsJob: #{count} essays to process"

    scope.find_each do |essay|
      AuthorMatcher.resolve(essay)
    rescue => e
      Rails.logger.warn "BackfillEssayAuthorsJob: skipped Essay##{essay.id} — #{e.message}"
    end

    Rails.logger.info "BackfillEssayAuthorsJob: complete"
  end
end
