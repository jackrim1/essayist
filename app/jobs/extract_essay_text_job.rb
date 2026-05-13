class ExtractEssayTextJob < ApplicationJob
  queue_as :default

  def perform(essay_id)
    essay = Essay.find(essay_id)
    return unless essay.original_file.attached?

    essay.original_file.open do |file|
      html    = PdfExtractor.call(file.path)
      words   = html.gsub(/<[^>]+>/, "").split.size
      essay.update!(content: html, word_count: words)
    end
  rescue => e
    Rails.logger.error "ExtractEssayTextJob failed for Essay##{essay_id}: #{e.message}"
    raise
  end
end
