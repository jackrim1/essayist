require "tempfile"
require "pdftotext"

# Extracts flowing text from a PDF and converts it to semantic HTML paragraphs.
#
# Strategy:
#   - Use pdftotext without -layout so it reconstructs reading order
#   - Strip page numbers and running headers/footers
#   - Rejoin soft-wrapped lines within a paragraph
#   - Split on blank lines to form paragraphs
class PdfExtractor
  # Lines that are just a number (page numbers)
  PAGE_NUMBER = /\A\s*\d+\s*\z/

  def self.call(file_path)
    new(file_path).extract
  end

  def initialize(file_path)
    @file_path = file_path
  end

  def extract
    pages = Pdftotext.pages(@file_path, layout: false, nopgbrk: true)
    raise "Could not extract text from PDF" if pages.empty?

    raw = pages.map(&:text).join("\n\n")
    to_html(raw)
  end

  private

  def to_html(raw)
    paragraphs = reconstruct_paragraphs(raw)
    paragraphs
      .map { |p| "<p class=\"prose-page\">#{CGI.escapeHTML(p)}</p>" }
      .join("\n")
  end

  def reconstruct_paragraphs(text)
    # Split into logical blocks separated by blank lines
    blocks = text.split(/\n{2,}/)

    blocks.flat_map { |block| join_soft_wraps(block) }
          .map(&:strip)
          .reject { |p| p.empty? || p.match?(PAGE_NUMBER) || p.length < 4 }
  end

  # Within a block, lines are either soft-wrapped (same paragraph) or hard breaks.
  # Heuristic: join a line onto the previous if it doesn't start with a capital
  # after a line that ended without sentence-terminal punctuation, OR if the
  # previous line ends with a hyphen (hyphenated word).
  def join_soft_wraps(block)
    lines = block.split("\n").map(&:strip).reject(&:empty?)
    return [] if lines.empty?

    result = []
    current = lines.first

    lines[1..].each do |line|
      next if line.match?(PAGE_NUMBER)

      if soft_wrap?(current, line)
        # Hyphenated word: drop the hyphen and join directly
        if current.end_with?("-")
          current = current.delete_suffix("-") + line
        else
          current = "#{current} #{line}"
        end
      else
        result << current
        current = line
      end
    end

    result << current
    result
  end

  # Returns true when `next_line` is a continuation of `prev_line` rather than
  # a new sentence/paragraph.
  def soft_wrap?(prev_line, next_line)
    return false if prev_line.empty? || next_line.empty?

    ends_mid_sentence = !prev_line.match?(/[.!?:'"]\s*\z/)
    hyphenated        = prev_line.end_with?("-")

    # Next line starts lowercase → almost certainly a continuation
    continues = next_line.match?(/\A[a-z]/)

    hyphenated || (ends_mid_sentence && continues)
  end
end
