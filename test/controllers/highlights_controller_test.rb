require "test_helper"

class HighlightsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user  = users(:one)
    @essay = essays(:one)
    sign_in @user
  end

  test "POST create saves highlight with parsed JSON anchor" do
    anchor = { startPara: 0, startOffset: 0, endPara: 0, endOffset: 18 }
    post essay_highlights_path(@essay), params: {
      highlight: { content: "It is not that we", color: "yellow", anchor: anchor.to_json }
    }, as: :turbo_stream

    assert_response :success
    h = Highlight.last
    assert_equal "It is not that we", h.content
    assert_equal 0, h.anchor["startPara"]
    assert_equal 18, h.anchor["endOffset"]
  end

  test "POST create with invalid JSON anchor falls back to empty anchor" do
    post essay_highlights_path(@essay), params: {
      highlight: { content: "Some text", color: "yellow", anchor: "{not-json" }
    }, as: :turbo_stream

    assert_response :success
    assert_equal({}, Highlight.last.anchor)
  end

  test "POST create returns turbo stream with highlights-list prepend" do
    post essay_highlights_path(@essay), params: {
      highlight: { content: "Some text", color: "blue", anchor: "{}"}
    }, as: :turbo_stream

    assert_response :success
    assert_includes response.body, "highlights-list"
  end

  test "POST create requires authentication" do
    sign_out @user
    post essay_highlights_path(@essay), params: {
      highlight: { content: "text", color: "yellow", anchor: "{}" }
    }
    assert_redirected_to new_user_session_path
  end

  test "DELETE destroy removes highlight" do
    highlight = Highlight.create!(essay: @essay, user: @user, content: "text", color: "yellow", anchor: {})
    delete essay_highlight_path(@essay, highlight), as: :turbo_stream
    assert_response :success
    assert_not Highlight.exists?(highlight.id)
  end

  test "DELETE destroy cannot remove another user's highlight" do
    other_user  = User.create!(email: "other@example.com", password: "password123")
    other_essay = other_user.essays.create!(title: "Other", last_read_position: 0, view_mode: :infinite)
    other_hl    = Highlight.create!(essay: other_essay, user: other_user, content: "text", color: "yellow", anchor: {})

    delete essay_highlight_path(other_essay, other_hl), as: :turbo_stream
    assert_response :not_found
  end
end
