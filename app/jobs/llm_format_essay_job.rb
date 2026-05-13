class LlmFormatEssayJob < ApplicationJob
  queue_as :default

  def perform(essay_id)
    essay = Essay.find(essay_id)
    return unless essay.original_file.attached?

    essay.original_file.open do |file|
      llm_html = PdfExtractor.llm_html(file.path)

      if PdfExtractor.looks_good?(llm_html, essay.content)
        words = PdfExtractor.word_count(llm_html)
        essay.update!(content: llm_html, word_count: words)
        Rails.logger.info "LlmFormatEssayJob: replaced content for Essay##{essay_id} (#{words} words)"
      else
        Rails.logger.warn "LlmFormatEssayJob: rejected LLM output for Essay##{essay_id}, keeping heuristic content"
      end
    end
  rescue => e
    Rails.logger.error "LlmFormatEssayJob failed for Essay##{essay_id}: #{e.message}"
    raise
  end
end
