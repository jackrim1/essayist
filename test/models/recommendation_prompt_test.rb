require "test_helper"

class RecommendationPromptTest < ActiveSupport::TestCase
  test "valid with kind and body" do
    p = RecommendationPrompt.new(kind: "author", body: "Some prompt")
    assert p.valid?
  end

  test "kind must be author or subject" do
    p = RecommendationPrompt.new(kind: "random", body: "x")
    assert_not p.valid?
    assert_includes p.errors[:kind], "is not included in the list"
  end

  test "body required" do
    p = RecommendationPrompt.new(kind: "author", body: nil)
    assert_not p.valid?
  end

  test "for returns prompt by kind" do
    prompt = RecommendationPrompt.for("author")
    assert_equal "author", prompt.kind
  end

  test "for raises on unknown kind" do
    assert_raises(ActiveRecord::RecordNotFound) { RecommendationPrompt.for("unknown") }
  end

  test "render interpolates all placeholders" do
    prompt = RecommendationPrompt.new(
      kind: "subject",
      body: "Read {{title}} by {{author}} about {{content_excerpt}}"
    )
    rendered = prompt.render(title: "Walden", author: "Thoreau", content_excerpt: "nature")
    assert_equal "Read Walden by Thoreau about nature", rendered
  end

  test "render leaves unmatched placeholders unchanged" do
    prompt = RecommendationPrompt.new(kind: "author", body: "Hello {{title}}")
    assert_equal "Hello Walden", prompt.render(title: "Walden", author: "x")
  end
end
