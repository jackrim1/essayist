require "test_helper"

class PdfExtractorTest < ActiveSupport::TestCase
  FRIEDMAN_PDF = Rails.root.join("test/fixtures/files/friedman.pdf").to_s
  FRIEDMAN_RAW = Rails.root.join("test/fixtures/files/friedman_raw.txt").read

  # ── Heuristic fallback (no API key required) ─────────────────────────────

  test "heuristic: produces paragraph tags" do
    html = extractor.send(:pdftotext_heuristic, FRIEDMAN_RAW)
    assert_includes html, '<p class="prose-page">'
  end

  test "heuristic: strips lone page numbers" do
    html = extractor.send(:pdftotext_heuristic, FRIEDMAN_RAW)
    # Page numbers (bare digits on their own line) must not become paragraphs
    refute_match(/<p class="prose-page">\d+<\/p>/, html)
  end

  test "heuristic: rejoins soft-wrapped lines into single paragraph" do
    html = extractor.send(:pdftotext_heuristic, FRIEDMAN_RAW)
    # The opening sentence is soft-wrapped across many lines.
    # Both sides of a line boundary must end up in the same <p>.
    assert_match(/<p[^>]*>[^<]*free-enterprise system[^<]*I am reminded[^<]*<\/p>/m, html)
  end

  test "heuristic: each paragraph has meaningful length" do
    html = extractor.send(:pdftotext_heuristic, FRIEDMAN_RAW)
    html.scan(/<p class="prose-page">(.*?)<\/p>/m).each do |match|
      assert match.first.length >= 4, "Suspiciously short paragraph: #{match.first.inspect}"
    end
  end

  test "heuristic: produces multiple paragraphs from full article" do
    html = extractor.send(:pdftotext_heuristic, FRIEDMAN_RAW)
    count = html.scan(/<p class="prose-page">/).length
    assert count >= 10, "Expected at least 10 paragraphs, got #{count}"
  end

  # ── pdftotext raw extraction ──────────────────────────────────────────────

  test "pdftotext_raw: returns substantial text from Friedman PDF" do
    raw = extractor.send(:pdftotext_raw)
    assert raw.length > 500, "Expected substantial text, got #{raw.length} chars"
    assert_includes raw, "social responsibilities"
    assert_includes raw, "Milton Friedman"
  end

  test "pdftotext_raw: returns empty string for missing file" do
    e = PdfExtractor.new("/tmp/does_not_exist.pdf")
    assert_equal "", e.send(:pdftotext_raw)
  end

  # ── Claude format path (requires ANTHROPIC_API_KEY) ──────────────────────

  test "claude_format: cleans raw Friedman text into well-formed HTML" do
    skip "ANTHROPIC_API_KEY not set" unless ENV["ANTHROPIC_API_KEY"].present?

    html = extractor.send(:claude_format, FRIEDMAN_RAW)

    assert_includes html, '<p class="prose-page">'
    assert_includes html, "social responsibilities"
    assert_includes html, "increase its profits"

    count = html.scan(/<p class="prose-page">/).length
    assert count >= 10, "Expected at least 10 paragraphs, got #{count}"
  end

  test "claude_format: strips page numbers" do
    skip "ANTHROPIC_API_KEY not set" unless ENV["ANTHROPIC_API_KEY"].present?

    raw_with_pages = "Opening sentence that wraps\nacross two lines.\n\n1\n\nSecond paragraph here."
    html = extractor.send(:claude_format, raw_with_pages)

    refute_match(/<p class="prose-page">1<\/p>/, html)
    assert_includes html, "Opening sentence"
    assert_includes html, "Second paragraph"
  end

  test "claude_format: rejoins soft-wrapped lines" do
    skip "ANTHROPIC_API_KEY not set" unless ENV["ANTHROPIC_API_KEY"].present?

    html = extractor.send(:claude_format, FRIEDMAN_RAW)
    # Both sides of the opening sentence's line break must be in the same paragraph
    assert_match(/<p[^>]*>[^<]*free-enterprise system[^<]*I am reminded[^<]*<\/p>/m, html)
  end

  # ── Full pipeline on real PDF ─────────────────────────────────────────────

  test "extract: full pipeline on Friedman PDF produces clean HTML" do
    skip "ANTHROPIC_API_KEY not set" unless ENV["ANTHROPIC_API_KEY"].present?

    html = PdfExtractor.call(FRIEDMAN_PDF)

    assert_includes html, '<p class="prose-page">'
    assert_includes html, "social responsibilities"

    count = html.scan(/<p class="prose-page">/).length
    assert count >= 10, "Expected at least 10 paragraphs, got #{count}"
  end

  private

  def extractor
    PdfExtractor.new(FRIEDMAN_PDF)
  end
end
