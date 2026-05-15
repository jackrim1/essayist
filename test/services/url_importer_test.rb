require "test_helper"

class UrlImporterTest < ActiveSupport::TestCase
  PDF_URL   = "https://example.com/paper.pdf"
  HTML_URL  = "https://example.com/essay"
  PDF_BYTES = File.binread(Rails.root.join("test/fixtures/files/friedman.pdf"))

  # ── PDF detection ──────────────────────────────────────────────────────────

  test "detects PDF by content-type, extracts content and metadata" do
    stub_fetch(PDF_URL, PDF_BYTES, "application/pdf", PDF_URL)
    PdfExtractor.stubs(:initial_html).returns('<p class="prose-page">Content.</p>')
    PdfExtractor.stubs(:raw_text).returns("As We May Think\nVannevar Bush\n\nConsider the problem...")
    stub_claude_metadata("As We May Think", "Vannevar Bush")

    result = UrlImporter.call(PDF_URL)

    assert_equal :pdf, result.type
    assert_includes result.content, "prose-page"
    assert_equal "As We May Think", result.title
    assert_equal "Vannevar Bush", result.author
    assert_not_nil result.pdf_io
    assert_equal "paper.pdf", result.pdf_filename
  end

  test "detects PDF by .pdf extension even when content-type is octet-stream" do
    stub_fetch(PDF_URL, PDF_BYTES, "application/octet-stream", PDF_URL)
    PdfExtractor.stubs(:initial_html).returns('<p class="prose-page">Content.</p>')
    PdfExtractor.stubs(:raw_text).returns("Some essay text")
    stub_claude_metadata(nil, nil)

    assert_equal :pdf, UrlImporter.call(PDF_URL).type
  end

  test "PDF returns nil title and author when metadata not found" do
    stub_fetch(PDF_URL, PDF_BYTES, "application/pdf", PDF_URL)
    PdfExtractor.stubs(:initial_html).returns('<p class="prose-page">Body.</p>')
    PdfExtractor.stubs(:raw_text).returns("Some text without clear title")
    stub_claude_metadata(nil, nil)

    result = UrlImporter.call(PDF_URL)

    # URL slug fallback: "paper" → "Paper"
    assert_equal "Paper", result.title
    assert_nil result.author
  end

  test "PDF result contains binary io sized to original bytes" do
    stub_fetch(PDF_URL, PDF_BYTES, "application/pdf", PDF_URL)
    PdfExtractor.stubs(:initial_html).returns('<p class="prose-page">Body.</p>')
    PdfExtractor.stubs(:raw_text).returns("Title\nAuthor\n\nBody text")
    stub_claude_metadata("Title", "Author")

    result = UrlImporter.call(PDF_URL)

    assert_equal PDF_BYTES.bytesize, result.pdf_io.read.bytesize
  end

  # ── HTML extraction ────────────────────────────────────────────────────────

  test "calls Claude for HTML pages and returns extracted content" do
    html = "<html><body><h1>Title</h1><p>Essay text here.</p></body></html>"
    stub_fetch(HTML_URL, html, "text/html", HTML_URL)

    stub_claude(<<~RESP)
      <!-- title: The Essay Title -->
      <!-- author: George Orwell -->
      <p class="prose-page">Essay text here.</p>
    RESP

    result = UrlImporter.call(HTML_URL)

    assert_equal :html, result.type
    assert_equal "The Essay Title", result.title
    assert_equal "George Orwell", result.author
    assert_includes result.content, '<p class="prose-page">Essay text here.</p>'
    refute_includes result.content, "<!--"
    assert_nil result.pdf_io
  end

  test "handles HTML page with no detectable title or author" do
    stub_fetch(HTML_URL, "<html><body><p>Text.</p></body></html>", "text/html", HTML_URL)
    stub_claude('<p class="prose-page">Text.</p>')

    result = UrlImporter.call(HTML_URL)

    # URL slug fallback: "essay" → "Essay"
    assert_equal "Essay", result.title
    assert_nil result.author
    assert_includes result.content, "prose-page"
  end

  test "HTML metadata hints are passed to Claude prompt" do
    html = <<~HTML
      <html>
        <head>
          <title>Page Title</title>
          <meta property="og:title" content="OG Title">
          <meta name="author" content="Jane Smith">
        </head>
        <body><p>Content.</p></body>
      </html>
    HTML
    stub_fetch(HTML_URL, html, "text/html", HTML_URL)

    captured_prompt = nil
    client_double   = mock
    messages_double = mock
    content_double  = mock(text: '<p class="prose-page">Content.</p>')
    message_double  = mock(content: [ content_double ])
    messages_double.stubs(:create).with { |args| captured_prompt = args[:messages].first[:content]; true }.returns(message_double)
    client_double.stubs(:messages).returns(messages_double)
    Anthropic::Client.stubs(:new).returns(client_double)

    UrlImporter.call(HTML_URL)

    assert_match(/og:title.*OG Title/i, captured_prompt)
    assert_match(/meta author.*Jane Smith/i, captured_prompt)
  end

  test "raises when Claude returns blank content for HTML" do
    stub_fetch(HTML_URL, "<html></html>", "text/html", HTML_URL)
    stub_claude("<!-- title: Something -->")

    err = assert_raises(RuntimeError) { UrlImporter.call(HTML_URL) }
    assert_match(/No essay content extracted/, err.message)
  end

  # ── URL title fallback ─────────────────────────────────────────────────────

  test "derives title from URL slug when Claude finds none" do
    stub_fetch("https://example.com/going-a-journey", "<html><body><p>Text.</p></body></html>", "text/html", "https://example.com/going-a-journey")
    stub_claude('<p class="prose-page">Text.</p>')

    result = UrlImporter.call("https://example.com/going-a-journey")

    assert_equal "Going A Journey", result.title
  end

  test "derives title from underscore slug for PDF" do
    url = "https://example.com/essays/going_a_journey.pdf"
    stub_fetch(url, PDF_BYTES, "application/pdf", url)
    PdfExtractor.stubs(:initial_html).returns('<p class="prose-page">Body.</p>')
    PdfExtractor.stubs(:raw_text).returns("some text")
    stub_claude_metadata(nil, nil)

    result = UrlImporter.call(url)

    assert_equal "Going A Journey", result.title
  end

  # ── URL validation ─────────────────────────────────────────────────────────

  test "raises on non-http scheme" do
    err = assert_raises(ArgumentError) { UrlImporter.call("ftp://example.com/file.pdf") }
    assert_match(/HTTP\/HTTPS/, err.message)
  end

  test "raises on HTTP error response" do
    stub_fetch_error("https://example.com/missing", RuntimeError.new("HTTP 404: Not Found"))

    err = assert_raises(RuntimeError) { UrlImporter.call("https://example.com/missing") }
    assert_match(/404/, err.message)
  end

  private

  def stub_fetch(url, body, content_type, final_url)
    UrlImporter.any_instance.stubs(:fetch).returns([ body, content_type, final_url ])
  end

  def stub_fetch_error(url, error)
    UrlImporter.any_instance.stubs(:fetch).raises(error)
  end

  # Stubs the Anthropic client — used for HTML extraction tests
  def stub_claude(text)
    content_double  = mock(text: text.strip)
    message_double  = mock(content: [ content_double ])
    messages_double = mock
    messages_double.stubs(:create).returns(message_double)
    client_double = mock
    client_double.stubs(:messages).returns(messages_double)
    Anthropic::Client.stubs(:new).returns(client_double)
  end

  # Stubs extract_metadata_from_text directly — used for PDF metadata tests
  def stub_claude_metadata(title, author)
    UrlImporter.any_instance.stubs(:extract_metadata_from_text).returns([ title, author ])
  end
end
