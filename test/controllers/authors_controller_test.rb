require "test_helper"

class AuthorsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user   = users(:one)
    @author = authors(:seneca)
    sign_in @user
  end

  test "GET show returns 200 and displays author name" do
    get author_path(@author)
    assert_response :success
    assert_select "p", text: /Seneca/
  end

  test "GET show lists essays by author" do
    get author_path(@author)
    assert_response :success
    assert_select "li", text: /On the Shortness of Life/
  end

  test "GET show requires authentication" do
    sign_out @user
    get author_path(@author)
    assert_redirected_to new_user_session_path
  end

  test "GET show is accessible for authors created by any user" do
    other_user   = User.create!(email: "stranger@example.com", password: "password123")
    other_author = Author.create!(name: "Another Author")

    get author_path(other_author)
    assert_response :success
  end
end
