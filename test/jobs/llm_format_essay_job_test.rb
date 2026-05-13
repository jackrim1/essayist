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
    good_llm_html = '<p class="prose-page">' + ("word " * 100) + "</p>"
    @essay.update_columns(content: '<p class="prose-page">' + ("word " * 100) + "</p>")

    @essay.original_file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/friedman.pdf")),
      filename: "friedman.pdf",
      content_type: "application/pdf"
    )

    PdfExtractor.stub(:llm_html, ->(_path) { good_llm_html }) do
      LlmFormatEssayJob.perform_now(@essay.id)
    end

    assert_equal good_llm_html, @essay.reload.content
  end

  test "keeps existing content when LLM output fails quality gate" do
    original = '<p class="prose-page">' + ("word " * 100) + "</p>"
    @essay.update_columns(content: original)

    @essay.original_file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/friedman.pdf")),
      filename: "friedman.pdf",
      content_type: "application/pdf"
    )

    # Return only 20 words — well below the 40% threshold
    bad_llm_html = '<p class="prose-page">' + ("word " * 20) + "</p>"
    PdfExtractor.stub(:llm_html, ->(_path) { bad_llm_html }) do
      LlmFormatEssayJob.perform_now(@essay.id)
    end

    assert_equal original, @essay.reload.content
  end

  test "keeps existing content when LLM raises an error" do
    original = @essay.content
    @essay.original_file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/friedman.pdf")),
      filename: "friedman.pdf",
      content_type: "application/pdf"
    )

    PdfExtractor.stub(:llm_html, ->(_path) { raise "API error" }) do
      assert_raises(RuntimeError) { LlmFormatEssayJob.perform_now(@essay.id) }
    end

    assert_equal original, @essay.reload.content
  end

  test "runs against real API and upgrades content" do
    skip "ANTHROPIC_API_KEY not set" unless ENV["ANTHROPIC_API_KEY"].present?

    @essay.original_file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/friedman.pdf")),
      filename: "friedman.pdf",
      content_type: "application/pdf"
    )
    baseline = PdfExtractor.initial_html(
      Rails.root.join("test/fixtures/files/friedman.pdf").to_s
    )
    @essay.update_columns(content: baseline)

    LlmFormatEssayJob.perform_now(@essay.id)

    @essay.reload
    assert @essay.content.present?
    assert_includes @essay.content, '<p class="prose-page">'
    assert @essay.word_count > 0
  end
end
