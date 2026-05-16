require "test_helper"

class RecommendationTest < ActiveSupport::TestCase
  test "valid with essay, user, kind, status" do
    r = Recommendation.new(essay: essays(:one), user: users(:one), kind: "author", status: :pending)
    assert r.valid?
  end

  test "kind must be author or subject" do
    r = Recommendation.new(essay: essays(:one), user: users(:one), kind: "other", status: :pending)
    assert_not r.valid?
    assert_includes r.errors[:kind], "is not included in the list"
  end

  test "kind presence required" do
    r = Recommendation.new(essay: essays(:one), user: users(:one), kind: nil, status: :pending)
    assert_not r.valid?
  end

  test "status enum transitions" do
    r = recommendations(:author_pending)
    assert r.pending?
    r.update!(status: :generating)
    assert r.generating?
    r.update!(status: :complete)
    assert r.complete?
  end

  test "turbo_stream_name includes id" do
    r = recommendations(:author_pending)
    assert_equal "recommendation_#{r.id}", r.turbo_stream_name
  end
end
