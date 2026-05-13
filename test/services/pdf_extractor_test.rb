require "test_helper"

class PdfExtractorTest < ActiveSupport::TestCase
  FRIEDMAN_PDF = Rails.root.join("test/fixtures/files/friedman.pdf").to_s
  FRIEDMAN_RAW = Rails.root.join("test/fixtures/files/friedman_raw.txt").read

  # ── raw_text (phase 1, pdftotext) ────────────────────────────────────────

  test "raw_text: returns substantial text from Friedman PDF" do
    raw = PdfExtractor.raw_text(FRIEDMAN_PDF)
    assert raw.length > 500
    assert_includes raw, "social responsibilities"
  end

  test "raw_text: returns empty string for missing file" do
    assert_equal "", PdfExtractor.raw_text("/tmp/does_not_exist.pdf")
  end

  # ── heuristic_html (phase 1, no API) ─────────────────────────────────────

  test "heuristic_html: produces paragraph tags" do
    html = PdfExtractor.heuristic_html(FRIEDMAN_RAW)
    assert_includes html, '<p class="prose-page">'
  end

  test "heuristic_html: strips lone page numbers" do
    html = PdfExtractor.heuristic_html(FRIEDMAN_RAW)
    refute_match(/<p class="prose-page">\d+<\/p>/, html)
  end

  test "heuristic_html: rejoins soft-wrapped lines into single paragraph" do
    html = PdfExtractor.heuristic_html(FRIEDMAN_RAW)
    assert_match(/<p[^>]*>[^<]*free-enterprise system[^<]*I am reminded[^<]*<\/p>/m, html)
  end

  test "heuristic_html: produces multiple paragraphs" do
    html = PdfExtractor.heuristic_html(FRIEDMAN_RAW)
    assert html.scan(/<p class="prose-page">/).length >= 10
  end

  # ── initial_html (phase 1 public entry point) ─────────────────────────────

  test "initial_html: returns heuristic HTML for text-layer PDF" do
    html = PdfExtractor.initial_html(FRIEDMAN_PDF)
    assert_includes html, '<p class="prose-page">'
    assert html.scan(/<p class="prose-page">/).length >= 10
  end

  test "initial_html: returns empty string for missing file" do
    assert_equal "", PdfExtractor.initial_html("/tmp/does_not_exist.pdf")
  end

  # ── looks_good? (quality gate) ───────────────────────────────────────────

  test "looks_good?: true when llm output is similar length to baseline" do
    baseline = '<p class="prose-page">' + ("word " * 100) + "</p>"
    llm      = '<p class="prose-page">' + ("word " * 90) + "</p>"
    assert PdfExtractor.looks_good?(llm, baseline)
  end

  test "looks_good?: false when llm output is less than 40% of baseline words" do
    baseline = '<p class="prose-page">' + ("word " * 100) + "</p>"
    llm      = '<p class="prose-page">' + ("word " * 30) + "</p>"
    refute PdfExtractor.looks_good?(llm, baseline)
  end

  test "looks_good?: false when llm output is more than double baseline" do
    baseline = '<p class="prose-page">' + ("word " * 100) + "</p>"
    llm      = '<p class="prose-page">' + ("word " * 250) + "</p>"
    refute PdfExtractor.looks_good?(llm, baseline)
  end

  test "looks_good?: false when llm output is empty" do
    refute PdfExtractor.looks_good?("", '<p class="prose-page">text</p>')
  end

  test "looks_good?: false when llm output has no paragraph tags" do
    refute PdfExtractor.looks_good?("just plain text", '<p class="prose-page">text</p>')
  end

  test "looks_good?: true when no baseline to compare against" do
    llm = '<p class="prose-page">Some content here</p>'
    assert PdfExtractor.looks_good?(llm, nil)
    assert PdfExtractor.looks_good?(llm, "")
  end

  # ── llm_html (phase 2, requires API key) ─────────────────────────────────

  test "llm_html: cleans Friedman PDF into well-formed HTML" do
    skip "ANTHROPIC_API_KEY not set" unless ENV["ANTHROPIC_API_KEY"].present?

    html = PdfExtractor.llm_html(FRIEDMAN_PDF)

    assert_includes html, '<p class="prose-page">'
    assert_includes html, "social responsibilities"
    assert html.scan(/<p class="prose-page">/).length >= 10
  end

  test "llm_html: output passes looks_good? against heuristic baseline" do
    skip "ANTHROPIC_API_KEY not set" unless ENV["ANTHROPIC_API_KEY"].present?

    baseline = PdfExtractor.initial_html(FRIEDMAN_PDF)
    llm      = PdfExtractor.llm_html(FRIEDMAN_PDF)

    assert PdfExtractor.looks_good?(llm, baseline),
      "LLM output did not pass quality gate vs heuristic baseline"
  end
end
