require "net/http"
require "uri"

# Fetches an essay from a URL. Handles two cases:
#   - Direct PDF link: downloads and runs pdftotext for immediate content.
#   - HTML page: sends raw HTML to Claude, which extracts just the essay text.
#
# Returns a Result value object. Raises on network or API failures.
class UrlImporter
  MODEL = "claude-sonnet-4-6"
  MAX_REDIRECTS = 5
  OPEN_TIMEOUT  = 10
  READ_TIMEOUT  = 30

  HTML_PROMPT = <<~PROMPT
    Extract the full essay text from this HTML page.

    Rules:
    - Wrap each paragraph in: <p class="prose-page">...</p>
    - Remove navigation, sidebars, ads, author bios, comments, footers, and other non-essay boilerplate
    - Preserve the complete essay text — do not summarise or omit anything
    - Output the essay title first as: <!-- title: Title Here -->
      Use the most accurate title you can find. Prefer the essay's own title over the page/site title.
      Clues to use (in order of preference): essay heading within the content, og:title/meta hints
      provided below, <title> tag, or derive a sensible title from the content itself.
    - Output the author next as: <!-- author: Author Name -->
      Only include a name if you are confident; omit the line entirely if uncertain.
    - Then output only the <p> tags — no other HTML or commentary

    %<hints>s
    HTML:
  PROMPT

  METADATA_PROMPT = <<~PROMPT
    From the text below (the opening of a document), identify the essay or article title and the author's name.

    Strategy:
    - The title is usually the first prominent line, often in ALL CAPS or title case, before the body text starts.
    - The author often appears just below the title, sometimes prefixed with "by", "By", or "BY".
    - If the title is not explicit, infer a short, accurate title from the subject matter.
    - Write null only if you truly cannot determine the value.

    Output ONLY these two lines:
    title: Title Here
    author: Author Name

    Text:
  PROMPT

  Result = Data.define(:type, :content, :title, :author, :pdf_io, :pdf_filename)

  def self.call(url)
    new(url).call
  end

  def initialize(url)
    @url = url
  end

  def call
    body, content_type, final_url = fetch(@url)

    if pdf_content?(content_type, final_url)
      from_pdf(body, final_url)
    else
      from_html(body, final_url)
    end
  end

  private

  def fetch(url, redirects = 0)
    raise ArgumentError, "Too many redirects" if redirects > MAX_REDIRECTS

    uri = URI.parse(url)
    raise ArgumentError, "Only HTTP/HTTPS URLs are supported" unless %w[http https].include?(uri.scheme)

    Net::HTTP.start(uri.host, uri.port,
                    use_ssl: uri.scheme == "https",
                    open_timeout: OPEN_TIMEOUT,
                    read_timeout: READ_TIMEOUT) do |http|
      req = Net::HTTP::Get.new(uri.request_uri)
      req["User-Agent"] = "Mozilla/5.0 (compatible; Essayist/1.0)"
      resp = http.request(req)

      case resp
      when Net::HTTPSuccess
        [ resp.body, resp["Content-Type"].to_s, url ]
      when Net::HTTPRedirection
        fetch(resp["location"], redirects + 1)
      else
        raise "HTTP #{resp.code}: #{resp.message}"
      end
    end
  end

  def pdf_content?(content_type, url)
    content_type.include?("pdf") || URI.parse(url).path.downcase.end_with?(".pdf")
  end

  def from_pdf(body, url)
    filename = File.basename(URI.parse(url).path).presence || "import.pdf"
    filename += ".pdf" unless filename.downcase.end_with?(".pdf")

    raw_text = ""
    content  = Tempfile.create([ "url_pdf", ".pdf" ], binmode: true) do |f|
      f.write(body)
      f.flush
      raw_text = PdfExtractor.raw_text(f.path)
      PdfExtractor.initial_html(f.path)
    end

    title, author = extract_metadata_from_text(raw_text)
    title ||= title_from_url(url)

    Result.new(
      type:         :pdf,
      content:      content,
      title:        title,
      author:       author,
      pdf_io:       StringIO.new(body.b),
      pdf_filename: filename
    )
  end

  def from_html(html_body, url = nil)
    utf8_body = html_body.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    hints     = html_metadata_hints(utf8_body)
    prompt    = format(HTML_PROMPT, hints: hints)

    response = claude_client.messages.create(
      model:      MODEL,
      max_tokens: 8192,
      messages:   [ { role: "user", content: prompt + utf8_body } ]
    )
    raw = response.content.first.text.strip

    title   = raw[/<!-- title:\s*(.+?)\s*-->/, 1]
    author  = raw[/<!-- author:\s*(.+?)\s*-->/, 1]
    content = raw.gsub(/<!--.*?-->/m, "").strip

    raise "No essay content extracted from page" if content.blank?

    title ||= title_from_url(url) if url
    Result.new(type: :html, content: content, title: title, author: author, pdf_io: nil, pdf_filename: nil)
  end

  # Pulls candidate title/author from HTML meta tags and headings to give Claude better signals.
  def html_metadata_hints(html)
    doc = Nokogiri::HTML(html)

    candidates = {
      "og:title"     => doc.at('meta[property="og:title"]')&.attr("content"),
      "twitter:title" => doc.at('meta[name="twitter:title"]')&.attr("content"),
      "<title> tag"  => doc.at("title")&.text&.strip,
      "<h1>"         => doc.at("h1")&.text&.strip,
      "og:author"    => doc.at('meta[property="article:author"]')&.attr("content"),
      "meta author"  => doc.at('meta[name="author"]')&.attr("content"),
    }.reject { |_, v| v.blank? }

    return "" if candidates.empty?

    lines = candidates.map { |k, v| "  #{k}: #{v}" }.join("\n")
    "Metadata hints extracted from the page:\n#{lines}\n\n"
  end

  def extract_metadata_from_text(text)
    return [ nil, nil ] if text.blank?

    sample   = text.first(3000)
    response = claude_client.messages.create(
      model:      MODEL,
      max_tokens: 150,
      messages:   [ { role: "user", content: METADATA_PROMPT + sample } ]
    )
    raw    = response.content.first.text.strip
    title  = raw[/^title:\s*(.+)/i, 1]&.strip
    author = raw[/^author:\s*(.+)/i, 1]&.strip
    title  = nil if title.nil? || title.casecmp("null").zero?
    author = nil if author.nil? || author.casecmp("null").zero?
    [ title, author ]
  end

  # Derives a human-readable title from the URL path as a last resort.
  # e.g. "going_a_jouney" → "Going a Journey", "some-thoughts-on-the-common-toad" → "Some Thoughts on the Common Toad"
  def title_from_url(url)
    path = URI.parse(url).path
    slug = path.split("/").reject(&:empty?).last.to_s
    slug = slug.sub(/\.[^.]+$/, "")   # strip extension
    return nil if slug.blank?

    slug.tr("-_", " ").split.map(&:capitalize).join(" ")
  rescue URI::InvalidURIError
    nil
  end

  def claude_client
    @claude_client ||= Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
  end
end
