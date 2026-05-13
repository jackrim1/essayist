require "test_helper"

class EssaysControllerTest < ActionDispatch::IntegrationTest
  include ActionDispatch::TestProcess::FixtureFile

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

  # ── Upload / create flow ──────────────────────────────────────────────────

  test "POST create with PDF enqueues LlmFormatEssayJob" do
    PdfExtractor.stubs(:initial_html).returns("")

    assert_enqueued_with(job: LlmFormatEssayJob) do
      post essays_path, params: { essay: {
        title: "Test Essay",
        original_file: fixture_file_upload("friedman.pdf", "application/pdf")
      } }
    end

    assert_redirected_to essay_path(Essay.last)
  end

  test "POST create sets initial content from pdftotext before redirect" do
    heuristic_html = '<p class="prose-page">Initial content from pdftotext.</p>'
    PdfExtractor.stubs(:initial_html).returns(heuristic_html)
    PdfExtractor.stubs(:word_count).returns(5)

    post essays_path, params: { essay: {
      title: "Test Essay",
      original_file: fixture_file_upload("friedman.pdf", "application/pdf")
    } }

    assert_equal heuristic_html, Essay.last.content
  end

  test "POST create without file attachment does not enqueue LLM job" do
    assert_no_enqueued_jobs(only: LlmFormatEssayJob) do
      post essays_path, params: { essay: { title: "No File Essay" } }
    end
    assert_redirected_to essay_path(Essay.last)
    assert_nil Essay.last.content
  end

  test "POST create with invalid params re-renders new" do
    post essays_path, params: { essay: { title: "" } }
    assert_response :unprocessable_entity
  end
end
