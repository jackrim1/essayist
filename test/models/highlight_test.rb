require "test_helper"

class HighlightTest < ActiveSupport::TestCase
  test "requires content" do
    h = Highlight.new(essay: essays(:one), user: users(:one), color: "yellow")
    assert_not h.valid?
    assert_includes h.errors[:content], "can't be blank"
  end

  test "color must be in allowed list" do
    h = Highlight.new(essay: essays(:one), user: users(:one), content: "text", color: "neon")
    assert_not h.valid?
  end

  test "valid highlight" do
    h = Highlight.new(essay: essays(:one), user: users(:one), content: "Some text", color: "blue")
    assert h.valid?
  end
end
