require "test_helper"

class EssayTest < ActiveSupport::TestCase
  test "requires title" do
    essay = Essay.new(user: users(:one))
    assert_not essay.valid?
    assert_includes essay.errors[:title], "can't be blank"
  end

  test "last_read_position must be between 0 and 1" do
    essay = essays(:one)
    essay.last_read_position = 1.5
    assert_not essay.valid?

    essay.last_read_position = 0.5
    assert essay.valid?
  end

  test "reading_percent converts position to integer percent" do
    essay = essays(:one)
    essay.last_read_position = 0.73
    assert_equal 73, essay.reading_percent
  end

  test "estimated_minutes based on 200 wpm" do
    essay = essays(:one)
    essay.word_count = 1000
    assert_equal 5, essay.estimated_minutes
  end

  test "view_mode enum" do
    essay = essays(:one)
    essay.view_mode = :paged
    assert essay.paged?
    assert_not essay.infinite?
  end
end
