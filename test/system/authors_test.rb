require "application_system_test_case"

class AuthorsTest < ApplicationSystemTestCase
  setup do
    @user   = users(:one)
    @essay  = essays(:one)
    @author = authors(:seneca)
    sign_in @user
  end

  test "author name on index card links to author page" do
    visit essays_path
    assert_selector "a[href='#{author_path(@author)}']"
  end

  test "clicking author name on index navigates to author page" do
    visit essays_path
    find("a[href='#{author_path(@author)}']").click
    assert_current_path author_path(@author)
    assert_text "Seneca"
  end

  test "author page lists essays by that author" do
    visit author_path(@author)
    assert_text @essay.title
  end

  test "author name on essay show page links to author page" do
    visit essay_path(@essay)
    assert_selector "a[href='#{author_path(@author)}']"
  end

  test "clicking author link on essay show navigates to author page" do
    visit essay_path(@essay)
    find("a[href='#{author_path(@author)}']").click
    assert_current_path author_path(@author)
    assert_text "Seneca"
  end

  test "author page shows essay count" do
    visit author_path(@author)
    assert_text "1 essay"
  end

  test "uploading essay with same author links to existing Author record" do
    AuthorMatcher.stubs(:resolve)
    # Create another essay for existing author
    other_essay = @user.essays.create!(
      title:             "Letters from a Stoic",
      author_name:       "Seneca",
      author:            @author,
      last_read_position: 0,
      view_mode:         :infinite
    )

    visit author_path(@author)
    assert_text "Letters from a Stoic"
    assert_text "2 essays"
  end
end
