require "test_helper"

class ImportEssayFromUrlJobTest < ActiveJob::TestCase
  setup do
    @essay = essays(:one)
    @url   = "https://example.com/essay"
  end

  test "updates essay content and word_count from HTML result" do
    html = '<p class="prose-page">Some essay content here for testing.</p>'
    result = UrlImporter::Result.new(
      type: :html, content: html, title: "Extracted Title",
      author: "Extracted Author", pdf_io: nil, pdf_filename: nil
    )
    UrlImporter.stubs(:call).returns(result)

    @essay.update_columns(author: "")
    ImportEssayFromUrlJob.perform_now(@essay.id, @url)

    @essay.reload
    assert_equal html, @essay.content
    assert_equal PdfExtractor.word_count(html), @essay.word_count
    assert_equal "Extracted Author", @essay.author
  end

  test "does not overwrite existing author" do
    html = '<p class="prose-page">Content.</p>'
    result = UrlImporter::Result.new(
      type: :html, content: html, title: nil,
      author: "New Author", pdf_io: nil, pdf_filename: nil
    )
    UrlImporter.stubs(:call).returns(result)

    @essay.update_columns(author: "Original Author")
    ImportEssayFromUrlJob.perform_now(@essay.id, @url)

    assert_equal "Original Author", @essay.reload.author
  end

  test "attaches PDF and enqueues LlmFormatEssayJob for PDF result" do
    pdf_bytes = File.binread(Rails.root.join("test/fixtures/files/friedman.pdf"))
    result = UrlImporter::Result.new(
      type:         :pdf,
      content:      '<p class="prose-page">Heuristic content.</p>',
      title:        nil,
      author:       nil,
      pdf_io:       StringIO.new(pdf_bytes),
      pdf_filename: "friedman.pdf"
    )
    UrlImporter.stubs(:call).returns(result)

    assert_enqueued_with(job: LlmFormatEssayJob) do
      ImportEssayFromUrlJob.perform_now(@essay.id, @url)
    end

    @essay.reload
    assert @essay.original_file.attached?
    assert_includes @essay.content, "prose-page"
  end

  test "does not enqueue LlmFormatEssayJob for HTML result" do
    result = UrlImporter::Result.new(
      type: :html, content: '<p class="prose-page">Done.</p>',
      title: nil, author: nil, pdf_io: nil, pdf_filename: nil
    )
    UrlImporter.stubs(:call).returns(result)

    assert_no_enqueued_jobs(only: LlmFormatEssayJob) do
      ImportEssayFromUrlJob.perform_now(@essay.id, @url)
    end
  end

  test "re-raises errors so retry_on can handle them" do
    UrlImporter.stubs(:call).raises(RuntimeError, "network error")

    assert_enqueued_jobs 1, only: ImportEssayFromUrlJob do
      ImportEssayFromUrlJob.perform_now(@essay.id, @url)
    end
  end

  test "real HTML import via UrlImporter against Orwell Foundation page" do
    skip "ANTHROPIC_API_KEY not set" unless ENV["ANTHROPIC_API_KEY"].present?

    result = UrlImporter.call(
      "https://www.orwellfoundation.com/the-orwell-foundation/orwell/essays-and-other-works/some-thoughts-on-the-common-toad/"
    )

    assert_equal :html, result.type
    assert result.content.present?, "content should be extracted"
    assert_includes result.content, '<p class="prose-page">'
    assert PdfExtractor.word_count(result.content) > 100, "Orwell essay should have substantial word count"
  end
end
