require "test_helper"

class EssayProgressTest < ActiveSupport::TestCase
  setup do
    @user  = users(:one)
    @essay = essays(:one)
  end

  test "last_read_position must be between 0 and 1" do
    progress = EssayProgress.new(user: @user, essay: @essay, last_read_position: 1.5)
    assert_not progress.valid?

    progress.last_read_position = 0.5
    assert progress.valid?
  end

  test "reading_percent converts position to integer percent" do
    progress = EssayProgress.new(user: @user, essay: @essay, last_read_position: 0.73)
    assert_equal 73, progress.reading_percent
  end

  test "view_mode enum" do
    progress = essay_progresses(:one)
    progress.view_mode = :paged
    assert progress.paged?
    assert_not progress.infinite?
  end
end
