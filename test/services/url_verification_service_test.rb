require "test_helper"

class UrlVerificationServiceTest < ActiveSupport::TestCase
  setup do
    @result = recommendation_results(:one)
  end

  test "returns verified: true when Claude confirms" do
    stub_fetch("<html><body>De Brevitate Vitae by Seneca full text</body></html>")
    stub_claude('{"verified": true, "note": "Page contains the full essay."}')

    outcome = UrlVerificationService.call(@result)
    assert outcome[:verified]
    assert_includes outcome[:note], "Page contains"
  end

  test "returns verified: false when Claude says no" do
    stub_fetch("<html><body>Homepage</body></html>")
    stub_claude('{"verified": false, "note": "This is just the site homepage."}')

    outcome = UrlVerificationService.call(@result)
    assert_not outcome[:verified]
  end

  test "strips markdown fences from Claude response" do
    stub_fetch("<html><body>Essay content</body></html>")
    stub_claude("```json\n{\"verified\": true, \"note\": \"Found it.\"}\n```")

    outcome = UrlVerificationService.call(@result)
    assert outcome[:verified]
  end

  test "returns verified: false on network error" do
    Net::HTTP.any_instance.stubs(:request).raises(SocketError, "getaddrinfo: nodename nor servname provided")

    outcome = UrlVerificationService.call(@result)
    assert_not outcome[:verified]
    assert_includes outcome[:note], "Verification error"
  end

  private

  def stub_fetch(body)
    response = Net::HTTPSuccess.new("1.1", "200", "OK")
    response.stubs(:body).returns(body)
    Net::HTTP.any_instance.stubs(:request).returns(response)
  end

  def stub_claude(response_text)
    content_double = stub(text: response_text)
    response_double = stub(content: [ content_double ])
    messages_double = stub(create: response_double)
    client_double   = stub(messages: messages_double)
    Anthropic::Client.stubs(:new).returns(client_double)
  end
end
