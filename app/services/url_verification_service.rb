require "net/http"
require "uri"

# Fetches a URL and asks Claude whether it actually contains the claimed essay.
# Returns a hash: { verified: true/false, note: "one sentence" }
class UrlVerificationService
  MODEL      = "claude-haiku-4-5-20251001"
  MAX_TOKENS = 256
  OPEN_TIMEOUT = 10
  READ_TIMEOUT = 20
  MAX_REDIRECTS = 5
  MAX_BODY_CHARS = 8_000

  def self.call(result)
    new(result).call
  end

  def initialize(result)
    @result = result
  end

  def call
    body = fetch_page(@result.url)
    excerpt = body.to_s.gsub(/<[^>]+>/, " ").squish.first(MAX_BODY_CHARS)

    prompt = <<~PROMPT.strip
      You are verifying whether a web page contains a specific essay.

      Essay title: "#{@result.title}"
      Essay author: #{@result.author}

      Page content (first #{MAX_BODY_CHARS} characters):
      #{excerpt}

      Does this page contain or link directly to the full text of that essay?
      Answer with a JSON object with exactly two keys:
      - verified: true or false
      - note: one sentence explaining what the page actually contains

      Return ONLY valid JSON. No markdown fences.
    PROMPT

    response = claude_client.messages.create(
      model:      MODEL,
      max_tokens: MAX_TOKENS,
      messages:   [ { role: "user", content: prompt } ]
    )

    raw = response.content.first.text.strip
    raw = raw.gsub(/\A```(?:json)?\s*/i, "").gsub(/\s*```\z/, "").strip
    parsed = JSON.parse(raw)

    { verified: parsed["verified"] == true, note: parsed["note"].to_s.first(500) }
  rescue => e
    { verified: false, note: "Verification error: #{e.message.first(200)}" }
  end

  private

  def fetch_page(url)
    uri = URI.parse(url)
    redirects = 0
    loop do
      raise "Too many redirects" if redirects >= MAX_REDIRECTS
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      request = Net::HTTP::Get.new(uri.request_uri)
      request["User-Agent"] = "Mozilla/5.0 (compatible; EssayistBot/1.0)"
      request["Accept"] = "text/html,application/xhtml+xml,application/pdf"

      response = http.request(request)

      case response
      when Net::HTTPSuccess
        return response.body.to_s.encode("UTF-8", invalid: :replace, undef: :replace)
      when Net::HTTPRedirection
        uri = URI.parse(response["Location"])
        redirects += 1
      else
        raise "HTTP #{response.code} for #{url}"
      end
    end
  end

  def claude_client
    @claude_client ||= Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
  end
end
