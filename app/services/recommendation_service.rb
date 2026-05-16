require "json"

# Calls Claude with a RecommendationPrompt and returns an array of result hashes.
# Raises on API failure or unparseable/empty response.
class RecommendationService
  MODEL      = "claude-sonnet-4-6"
  MAX_TOKENS = 4000

  def self.call(recommendation)
    new(recommendation).call
  end

  def initialize(recommendation)
    @recommendation = recommendation
    @essay          = recommendation.essay
  end

  def call
    prompt_template = RecommendationPrompt.for(@recommendation.kind)
    content_excerpt = plain_text_excerpt(@essay.content, 800)

    prompt = prompt_template.render(
      title:           @essay.title.to_s,
      author:          @essay.author.to_s,
      content_excerpt: content_excerpt
    )

    response = claude_client.messages.create(
      model:      MODEL,
      max_tokens: MAX_TOKENS,
      messages:   [ { role: "user", content: prompt } ]
    )

    raw = response.content.first.text.strip
    # Strip markdown fences if Claude wraps JSON in ```json ... ```
    raw = raw.gsub(/\A```(?:json)?\s*/i, "").gsub(/\s*```\z/, "").strip

    results = JSON.parse(raw)
    raise "Expected a JSON array of recommendations" unless results.is_a?(Array) && results.any?

    results
  rescue JSON::ParserError => e
    raise "Claude returned unparseable JSON: #{e.message}"
  end

  private

  def plain_text_excerpt(html, max_chars)
    return "" if html.blank?
    Nokogiri::HTML.fragment(html.to_s).text.squish.first(max_chars)
  end

  def claude_client
    @claude_client ||= Anthropic::Client.new(api_key: ENV.fetch("ANTHROPIC_API_KEY"))
  end
end
