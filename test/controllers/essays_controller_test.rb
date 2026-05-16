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

  test "index displays essay title" do
    get essays_path
    assert_select "a", text: @essay.title
  end

  test "index displays author name linked to author page" do
    get essays_path
    assert_select "a[href='#{author_path(@essay.author)}']", text: @essay.author_name
  end

  test "GET show returns 200" do
    get essay_path(@essay)
    assert_response :success
  end

  test "show displays author name linked to author page" do
    get essay_path(@essay)
    assert_select "a[href='#{author_path(@essay.author)}']", text: @essay.author_name
  end

  test "show page subscribes to essay turbo stream" do
    get essay_path(@essay)
    assert_select "turbo-cable-stream-source[channel='Turbo::StreamsChannel']"
  end

  test "show page wraps content in turbo-replaceable div" do
    get essay_path(@essay)
    assert_select "##{ActionView::RecordIdentifier.dom_id(@essay, :content)}"
  end

  test "show page renders spinner when essay has no content" do
    @essay.update_columns(content: nil)
    get essay_path(@essay)
    assert_select ".animate-spin"
  end

  # Regression: overflow-x-hidden on <body> combined with h-full disables
  # window scrolling on iOS, breaking scroll-position tracking entirely.
  test "show page body tag does not carry overflow-hidden classes" do
    get essay_path(@essay)
    assert_select "body" do |nodes|
      cls = nodes.first["class"].to_s
      assert_not cls.include?("overflow-hidden"),   "overflow-hidden on body kills iOS scrolling"
      assert_not cls.include?("overflow-x-hidden"), "overflow-x-hidden on body kills iOS scrolling"
    end
  end

  test "show page renders scroll-position controller with save URL and position" do
    get essay_path(@essay)
    assert_select "[data-controller~='scroll-position']" do |nodes|
      el = nodes.first
      assert el["data-scroll-position-save-url-value"].present?,
             "scroll-position save URL must be set"
      assert el["data-scroll-position-position-value"].present?,
             "scroll-position position value must be set"
    end
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

  # ── PWA / safe area ──────────────────────────────────────────────────────────

  test "index header has pt-safe for iOS status bar clearance" do
    get essays_path
    assert_select "header.pt-safe"
  end

  test "show header has pt-safe for iOS status bar clearance" do
    get essay_path(@essay)
    assert_select "header.pt-safe"
  end

  # ── Index layout ─────────────────────────────────────────────────────────────

  test "index renders search input" do
    get essays_path
    assert_select "input[data-essay-search-target='input']"
  end

  test "index search input and icon are in the same container" do
    get essays_path
    assert_select "[data-controller='essay-search'] .flex.items-center input"
  end

  test "index search dropdown is absolutely positioned" do
    get essays_path
    assert_select "ul[data-essay-search-target='results']"
  end

  test "index always renders highlights panel" do
    get essays_path
    assert_select "#highlights-panel"
    assert_select "#highlights-panel h2", text: /Highlights/i
  end

  test "index highlights panel shows empty state when no highlights" do
    @user.highlights.destroy_all
    get essays_path
    assert_select "#highlights-panel", text: /No highlights yet/
  end

  # ── Search ───────────────────────────────────────────────────────────────────

  test "GET search returns JSON with matching essays" do
    get essays_search_path, params: { q: "Shortness" }, as: :json
    assert_response :success
    data = JSON.parse(response.body)
    assert_kind_of Array, data
    assert data.any? { |e| e["title"] =~ /Shortness/ }
  end

  test "GET search returns empty array for short query" do
    get essays_search_path, params: { q: "S" }, as: :json
    assert_response :success
    assert_equal [], JSON.parse(response.body)
  end

  test "GET search requires authentication" do
    sign_out @user
    get essays_search_path, params: { q: "test" }, as: :json
    assert_response :unauthorized
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

  # ── URL import flow ───────────────────────────────────────────────────────

  test "POST create with source_url enqueues ImportEssayFromUrlJob" do
    assert_enqueued_with(job: ImportEssayFromUrlJob) do
      post essays_path, params: { essay: {
        title: "Common Toad",
        source_url: "https://www.orwellfoundation.com/the-orwell-foundation/orwell/essays-and-other-works/some-thoughts-on-the-common-toad/"
      } }
    end

    assert_redirected_to essay_path(Essay.last)
    assert_equal "https://www.orwellfoundation.com/the-orwell-foundation/orwell/essays-and-other-works/some-thoughts-on-the-common-toad/", Essay.last.source_url
  end

  test "POST create with source_url does not enqueue LlmFormatEssayJob" do
    assert_no_enqueued_jobs(only: LlmFormatEssayJob) do
      post essays_path, params: { essay: {
        title: "Test",
        source_url: "https://example.com/essay"
      } }
    end
  end

  test "POST create with neither file nor url does not enqueue any import job" do
    assert_no_enqueued_jobs(only: [ ImportEssayFromUrlJob, LlmFormatEssayJob ]) do
      post essays_path, params: { essay: { title: "No Source Essay" } }
    end
    assert_redirected_to essay_path(Essay.last)
  end

  test "POST create with invalid source_url re-renders new" do
    post essays_path, params: { essay: { title: "Bad URL", source_url: "not-a-url" } }
    assert_response :unprocessable_entity
  end
end
