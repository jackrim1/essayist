require "test_helper"

class RecommendationResultTest < ActiveSupport::TestCase
  def build_result(overrides = {})
    RecommendationResult.new({
      recommendation: recommendations(:subject_complete),
      position:    1,
      title:       "Some Essay",
      author:      "Some Author",
      description: "A great essay."
    }.merge(overrides))
  end

  test "valid with required fields" do
    assert build_result.valid?
  end

  test "requires title" do
    assert_not build_result(title: nil).valid?
  end

  test "requires author" do
    assert_not build_result(author: nil).valid?
  end

  test "requires description" do
    assert_not build_result(description: nil).valid?
  end

  test "position must be a positive integer" do
    assert_not build_result(position: 0).valid?
    assert_not build_result(position: -1).valid?
    assert build_result(position: 1).valid?
  end

  test "search_url falls back to google search" do
    r = build_result(title: "On Liberty", author: "Mill", search_query: nil)
    assert_includes r.search_url, "google.com/search"
    assert_includes r.search_url, CGI.escape('"On Liberty" by Mill essay')
  end

  test "search_url uses search_query when present" do
    r = build_result(search_query: "On Liberty Mill PDF")
    assert_includes r.search_url, CGI.escape("On Liberty Mill PDF")
  end

  test "importable? only when url present and verified" do
    r = build_result(url: "https://example.com", url_verified: true)
    assert r.importable?

    r.url_verified = false
    assert_not r.importable?

    r.url_verified = nil
    assert_not r.importable?

    r.url = nil
    r.url_verified = true
    assert_not r.importable?
  end

  test "verification_pending? when url present and url_verified nil" do
    r = build_result(url: "https://example.com", url_verified: nil)
    assert r.verification_pending?

    r.url_verified = true
    assert_not r.verification_pending?

    r.url = nil
    r.url_verified = nil
    assert_not r.verification_pending?
  end
end
