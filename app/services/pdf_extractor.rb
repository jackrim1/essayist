require "base64"

# Extracts text from a PDF and converts it to semantic HTML paragraphs.
#
# Strategy:
#   1. pdftotext — fast, free, gets the raw text layer
#   2. Claude format — send the raw text to Claude to clean paragraph breaks,
#      rejoin soft-wrapped lines, and strip headers/footers
#   3. Claude OCR (fallback) — for image-only PDFs with no text layer,
#      send the PDF bytes directly to Claude's document vision API
#   4. pdftotext heuristics (last resort) — regex-based paragraph reconstruction
class PdfExtractor
  MODEL = "claude-sonnet-4-6"

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
  MIN_TEXT_LENGTH = 200

  def self.call(file_path)
    new(file_path).extract
  end

  def initialize(file_path)
    @file_path = file_path
  end

  def extract
    raw = pdftotext_raw

    if raw.length >= MIN_TEXT_LENGTH
      claude_format(raw)
    else
      Rails.logger.info "[PdfExtractor] No text layer found, using Claude OCR"
      claude_ocr
    end
  rescue => e
    Rails.logger.warn "[PdfExtractor] Claude failed (#{e.class}: #{e.message}), falling back to heuristic extraction"
    pdftotext_heuristic(pdftotext_raw)
  end

  private

  # ── pdftotext ────────────────────────────────────────────────────────────

  def pdftotext_raw
    require "tempfile"
    require "pdftotext"

    pages = Pdftotext.pages(@file_path, layout: false, nopgbrk: true)
    return "" if pages.empty?

    pages.map(&:text).join("\n\n")
  rescue
    ""
  end

  # ── Claude: format raw text (primary path for text-layer PDFs) ───────────

  def claude_format(raw_text)
    response = claude_client.messages.create(
      model: MODEL,
      max_tokens: 8192,
      messages: [{
        role: "user",
        content: FORMAT_PROMPT + raw_text
      }]
    )

    html = response.content.first.text.strip
    validate_html!(html)
    html
  end

  # ── Claude: OCR via document vision (fallback for image-only PDFs) ───────

  def claude_ocr
    pdf_b64 = Base64.strict_encode64(File.binread(@file_path))

    response = claude_client.messages.create(
      model: MODEL,
      max_tokens: 8192,
      messages: [{
        role: "user",
        content: [
          {
            type: "document",
            source: { type: "base64", media_type: "application/pdf", data: pdf_b64 }
          },
          { type: "text", text: OCR_PROMPT }
        ]
      }]
    )

    html = response.content.first.text.strip
    validate_html!(html)
    html
  end

  def claude_client
    @claude_client ||= Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
  end

  def validate_html!(html)
    raise "Empty response from Claude" if html.empty?
    raise "Response missing paragraph tags" unless html.include?("<p")
    html
  end

  # ── Heuristic fallback (last resort) ─────────────────────────────────────

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
