require "base64"

# Two-phase PDF text extraction.
#
# Phase 1 (sync, fast): pdftotext → heuristic HTML paragraph reconstruction.
#   Call PdfExtractor.initial_html(file_path) right after upload so the user
#   sees content immediately. Returns "" for image-only PDFs.
#
# Phase 2 (async, API): Claude reformats the text, or OCRs image-only PDFs.
#   Call PdfExtractor.llm_html(file_path). Then use looks_good? to decide
#   whether to replace the Phase 1 content.
class PdfExtractor
  MODEL = "claude-sonnet-4-6"
  MIN_TEXT_LENGTH = 200

  FORMAT_PROMPT = <<~PROMPT
    The text below was extracted from a PDF using pdftotext. Clean it up and reformat it as HTML paragraphs.

    Rules:
    - Wrap each paragraph in: <p class="prose-page">...</p>
    - Rejoin lines that are soft-wrapped mid-sentence into a single paragraph
    - Remove page numbers and repeated running headers/footers
    - Preserve the complete text — do not summarise or omit anything
    - Do not add any other HTML elements or markup
    - Output ONLY the <p> tags — no preamble or commentary

    Raw text:
  PROMPT

  OCR_PROMPT = <<~PROMPT
    Transcribe the full text of this PDF into HTML paragraphs, word for word.

    Rules:
    - Wrap each paragraph in: <p class="prose-page">...</p>
    - Rejoin soft-wrapped lines into single paragraphs
    - Remove page numbers and running headers/footers
    - Output ONLY the <p> tags — no preamble or commentary
  PROMPT

  PAGE_NUMBER = /\A\s*\d+\s*\z/

  # ── Public phase-1 API ───────────────────────────────────────────────────

  # Fast sync path: pdftotext + heuristic paragraph reconstruction.
  # Returns empty string for image-only PDFs (no text layer).
  def self.initial_html(file_path)
    raw = raw_text(file_path)
    return "" if raw.length < MIN_TEXT_LENGTH

    heuristic_html(raw)
  end

  # ── Public phase-2 API ───────────────────────────────────────────────────

  # Slow async path: Claude cleans up a text-layer PDF, or OCRs an image PDF.
  # Raises on API failure — caller should handle and keep Phase 1 content.
  def self.llm_html(file_path)
    raw = raw_text(file_path)
    if raw.length >= MIN_TEXT_LENGTH
      new(file_path).send(:claude_format, raw)
    else
      new(file_path).send(:claude_ocr)
    end
  end

  # Quality gate: is +llm_html+ a trustworthy replacement for +baseline_html+?
  # Rejects empty output, missing paragraph tags, and severe length divergence.
  def self.looks_good?(llm_html, baseline_html)
    return false if llm_html.blank?
    return false unless llm_html.include?("<p")

    # If we have a baseline, word-count must be within a reasonable band.
    # LLM can be shorter (removes headers/footers) but shouldn't be half the
    # length or double it.
    if baseline_html.present?
      llm_words      = word_count(llm_html)
      baseline_words = word_count(baseline_html)
      return false if baseline_words > 0 && llm_words < baseline_words * 0.4
      return false if baseline_words > 0 && llm_words > baseline_words * 2.0
    end

    true
  end

  # ── Shared helpers ───────────────────────────────────────────────────────

  def self.raw_text(file_path)
    require "pdftotext"
    pages = Pdftotext.pages(file_path, layout: false, nopgbrk: true)
    return "" if pages.empty?

    pages.map(&:text).join("\n\n")
  rescue
    ""
  end

  def self.heuristic_html(raw)
    new(nil).send(:pdftotext_heuristic, raw)
  end

  def self.word_count(html)
    html.gsub(/<[^>]+>/, "").split.size
  end

  # ── Legacy class-method entry point (kept for tests) ─────────────────────

  def self.call(file_path)
    llm_html(file_path)
  rescue => e
    Rails.logger.warn "[PdfExtractor] Claude failed (#{e.class}: #{e.message}), falling back to heuristic"
    initial_html(file_path)
  end

  # ── Instance (private detail) ────────────────────────────────────────────

  def initialize(file_path)
    @file_path = file_path
  end

  private

  def claude_format(raw_text)
    response = claude_client.messages.create(
      model: MODEL,
      max_tokens: 8192,
      messages: [{ role: "user", content: FORMAT_PROMPT + raw_text }]
    )
    html = response.content.first.text.strip
    validate_html!(html)
  end

  def claude_ocr
    pdf_b64 = Base64.strict_encode64(File.binread(@file_path))
    response = claude_client.messages.create(
      model: MODEL,
      max_tokens: 8192,
      messages: [{
        role: "user",
        content: [
          { type: "document", source: { type: "base64", media_type: "application/pdf", data: pdf_b64 } },
          { type: "text", text: OCR_PROMPT }
        ]
      }]
    )
    html = response.content.first.text.strip
    validate_html!(html)
  end

  def claude_client
    @claude_client ||= Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
  end

  def validate_html!(html)
    raise "Empty response from Claude" if html.empty?
    raise "Response missing paragraph tags" unless html.include?("<p")
    html
  end

  def pdftotext_heuristic(raw)
    paragraphs = reconstruct_paragraphs(raw)
    paragraphs
      .map { |p| "<p class=\"prose-page\">#{CGI.escapeHTML(p)}</p>" }
      .join("\n")
  end

  def reconstruct_paragraphs(text)
    blocks = text.split(/\n{2,}/)
    blocks.flat_map { |block| join_soft_wraps(block) }
          .map(&:strip)
          .reject { |p| p.empty? || p.match?(PAGE_NUMBER) || p.length < 4 }
  end

  def join_soft_wraps(block)
    lines = block.split("\n").map(&:strip).reject(&:empty?)
    return [] if lines.empty?

    result  = []
    current = lines.first

    lines[1..].each do |line|
      next if line.match?(PAGE_NUMBER)

      if soft_wrap?(current, line)
        current = current.end_with?("-") ? current.delete_suffix("-") + line : "#{current} #{line}"
      else
        result << current
        current = line
      end
    end

    result << current
    result
  end

  def soft_wrap?(prev_line, next_line)
    return false if prev_line.empty? || next_line.empty?

    ends_mid_sentence = !prev_line.match?(/[.!?:'"]\s*\z/)
    hyphenated        = prev_line.end_with?("-")
    continues         = next_line.match?(/\A[a-z]/)

    hyphenated || (ends_mid_sentence && continues)
  end
end
