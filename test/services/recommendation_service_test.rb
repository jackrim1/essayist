require "test_helper"

class RecommendationServiceTest < ActiveSupport::TestCase
  VALID_RESULTS = [
    { "title" => "Essay A", "author" => "Author A", "description" => "Desc A", "url" => nil, "url_type" => nil },
    { "title" => "Essay B", "author" => "Author B", "description" => "Desc B", "url" => "https://example.com/b", "url_type" => "html" },
    { "title" => "Essay C", "author" => "Author C", "description" => "Desc C", "url" => nil, "url_type" => nil },
    { "title" => "Essay D", "author" => "Author D", "description" => "Desc D", "url" => nil, "url_type" => nil },
    { "title" => "Essay E", "author" => "Author E", "description" => "Desc E", "url" => nil, "url_type" => nil }
  ].freeze

  setup do
    @recommendation = recommendations(:author_pending)
  end

  test "returns parsed array on success" do
    stub_claude(VALID_RESULTS.to_json)
    results = RecommendationService.call(@recommendation)
    assert_equal 5, results.length
    assert_equal "Essay A", results.first["title"]
  end

  test "strips markdown fences from response" do
    stub_claude("```json\n#{VALID_RESULTS.to_json}\n```")
    results = RecommendationService.call(@recommendation)
    assert_equal 5, results.length
  end

  test "raises on empty array" do
    stub_claude("[]")
    assert_raises(RuntimeError) { RecommendationService.call(@recommendation) }
  end

  test "raises on non-array JSON" do
    stub_claude('{"error": "bad"}')
    assert_raises(RuntimeError) { RecommendationService.call(@recommendation) }
  end

  test "raises on unparseable response" do
    stub_claude("Not JSON at all")
    assert_raises(RuntimeError) { RecommendationService.call(@recommendation) }
  end

  test "raises RecordNotFound when the prompt row is missing" do
    RecommendationPrompt.delete_all
    assert_raises(ActiveRecord::RecordNotFound) { RecommendationService.call(@recommendation) }
  end

  private

  def stub_claude(response_text)
    content_double = stub(text: response_text)
    response_double = stub(content: [ content_double ])
    messages_double = stub(create: response_double)
    client_double   = stub(messages: messages_double)
    Anthropic::Client.stubs(:new).returns(client_double)
  end
end
