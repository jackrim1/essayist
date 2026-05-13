require "test_helper"

class EssaysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user  = users(:one)
    @essay = essays(:one)
    sign_in @user
  end

  test "GET index returns 200" do
    get essays_path
    assert_response :success
  end

  test "GET show returns 200" do
    get essay_path(@essay)
    assert_response :success
  end

  test "GET new returns 200" do
    get new_essay_path
    assert_response :success
  end

  test "GET edit returns 200" do
    get edit_essay_path(@essay)
    assert_response :success
  end

  test "PATCH update changes title" do
    patch essay_path(@essay), params: { essay: { title: "New Title" } }
    assert_redirected_to essay_path(@essay)
    assert_equal "New Title", @essay.reload.title
  end

  test "DELETE destroy removes essay" do
    assert_difference "Essay.count", -1 do
      delete essay_path(@essay)
    end
    assert_redirected_to essays_path
  end

  test "unauthenticated user is redirected to sign in" do
    sign_out @user
    get essays_path
    assert_redirected_to new_user_session_path
  end
end
