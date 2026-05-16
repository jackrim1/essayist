class ImportEssayFromUrlJob < ApplicationJob
  queue_as :default

  def perform(essay_id, url)
    essay = Essay.find(essay_id)
    result = UrlImporter.call(url)

    if result.type == :pdf && result.pdf_io
      essay.original_file.attach(
        io:           result.pdf_io,
        filename:     result.pdf_filename,
        content_type: "application/pdf"
      )
    end

    attrs = {}
    if result.content.present?
      attrs[:content]         = result.content
      attrs[:word_count]      = PdfExtractor.word_count(result.content)
      attrs[:content_simhash] = DuplicateDetector.simhash(result.content)
    end
    attrs[:title]  = result.title  if result.title.present?  && essay.title.blank?
    attrs[:author_name] = result.author if result.author.present? && essay.author_name.blank?
    essay.update_columns(**attrs) if attrs.any?
    AuthorMatcher.resolve(essay) if attrs[:author_name].present?

    LlmFormatEssayJob.perform_later(essay_id) if result.type == :pdf
  rescue => e
    Rails.logger.error "ImportEssayFromUrlJob failed for Essay##{essay_id}: #{e.message}"
    raise
  end
end
