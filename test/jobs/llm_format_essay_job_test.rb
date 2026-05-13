require "test_helper"

class LlmFormatEssayJobTest < ActiveJob::TestCase
  include ActionDispatch::TestProcess::FixtureFile

  setup do
    @essay = essays(:one)
  end

  test "does nothing when essay has no attached file" do
    original_content = @essay.content
    LlmFormatEssayJob.perform_now(@essay.id)
    assert_equal original_content, @essay.reload.content
  end

  test "replaces content when LLM output passes quality gate" do
    good_html = '<p class="prose-page">' + ("word " * 100) + "</p>"
    @essay.update_columns(content: '<p class="prose-page">' + ("word " * 95) + "</p>")
    attach_pdf

    PdfExtractor.stubs(:llm_html).returns(good_html)
    LlmFormatEssayJob.perform_now(@essay.id)

    assert_equal good_html, @essay.reload.content
  end

  test "keeps existing content when LLM output fails quality gate" do
    original = '<p class="prose-page">' + ("word " * 100) + "</p>"
    @essay.update_columns(content: original)
    attach_pdf

    # 20 words is well below the 40% threshold of 100
    PdfExtractor.stubs(:llm_html).returns('<p class="prose-page">' + ("word " * 20) + "</p>")
    LlmFormatEssayJob.perform_now(@essay.id)

    assert_equal original, @essay.reload.content
  end

  test "keeps existing content and enqueues retry when LLM errors" do
    original = @essay.content
    attach_pdf

    PdfExtractor.stubs(:llm_html).raises(RuntimeError)

    # retry_on StandardError in ApplicationJob means the error triggers a retry
    # rather than propagating — verify content is unchanged and retry is queued
    assert_enqueued_jobs 1, only: LlmFormatEssayJob do
      LlmFormatEssayJob.perform_now(@essay.id)
    end
    assert_equal original, @essay.reload.content
  end

  test "runs against real API and upgrades content" do
    skip "ANTHROPIC_API_KEY not set" unless ENV["ANTHROPIC_API_KEY"].present?

    attach_pdf
    baseline = PdfExtractor.initial_html(Rails.root.join("test/fixtures/files/friedman.pdf").to_s)
    @essay.update_columns(content: baseline)

    LlmFormatEssayJob.perform_now(@essay.id)

    @essay.reload
    assert @essay.content.present?
    assert_includes @essay.content, '<p class="prose-page">'
    assert @essay.word_count > 0
  end

  private

  def attach_pdf
    @essay.original_file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/friedman.pdf")),
      filename: "friedman.pdf",
      content_type: "application/pdf"
    )
  end
end
