require "test_helper"

class EssayTest < ActiveSupport::TestCase
  test "requires title" do
    essay = Essay.new
    assert_not essay.valid?
    assert_includes essay.errors[:title], "can't be blank"
  end

  test "estimated_minutes based on 200 wpm" do
    essay = essays(:one)
    essay.word_count = 1000
    assert_equal 5, essay.estimated_minutes
  end

  test "estimated_minutes is nil when word_count is nil" do
    essay = Essay.new(title: "Test")
    assert_nil essay.estimated_minutes
  end
end
