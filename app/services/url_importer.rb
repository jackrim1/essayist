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
    - If you can identify the essay title, output it first as: <!-- title: Title Here -->
    - If you can identify the author, output it next as: <!-- author: Author Name -->
    - Then output only the <p> tags — no other HTML or commentary

    HTML:
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
      from_html(body)
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

    content = Tempfile.create([ "url_pdf", ".pdf" ], binmode: true) do |f|
      f.write(body)
      f.flush
      PdfExtractor.initial_html(f.path)
    end

    Result.new(
      type:         :pdf,
      content:      content,
      title:        nil,
      author:       nil,
      pdf_io:       StringIO.new(body.b),
      pdf_filename: filename
    )
  end

  def from_html(html_body)
    response = claude_client.messages.create(
      model:      MODEL,
      max_tokens: 8192,
      messages:   [ { role: "user", content: HTML_PROMPT + html_body } ]
    )
    raw = response.content.first.text.strip

    title   = raw[/<!-- title:\s*(.+?)\s*-->/, 1]
    author  = raw[/<!-- author:\s*(.+?)\s*-->/, 1]
    content = raw.gsub(/<!--.*?-->/m, "").strip

    raise "No essay content extracted from page" if content.blank?

    Result.new(type: :html, content: content, title: title, author: author, pdf_io: nil, pdf_filename: nil)
  end

  def claude_client
    @claude_client ||= Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
  end
end
