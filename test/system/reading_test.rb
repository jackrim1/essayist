require "application_system_test_case"

class ReadingTest < ApplicationSystemTestCase
  LONG_CONTENT = (('<p class="prose-page">' + ("word " * 200) + "</p>") * 30).freeze

  setup do
    @user  = users(:one)
    @essay = essays(:one)
    sign_in @user
  end

  test "library shows uploaded essays" do
    visit essays_path
    assert_text @essay.title
  end

  test "reader renders essay content" do
    @essay.update!(content: '<p class="prose-page">Hello world</p>')
    visit essay_path(@essay)
    assert_text "Hello world"
  end

  test "reader has progress bar" do
    visit essay_path(@essay)
    assert_selector "#reading-progress", visible: :any
  end

  test "reader settings drawer opens and shows font size controls" do
    visit essay_path(@essay)
    find("[data-action='reader-settings#openDrawer']").click
    assert_text "Text size"
    assert_text "Appearance"
  end

  test "dark mode toggle on library page" do
    visit essays_path
    page.execute_script("localStorage.removeItem('essayist:theme'); document.documentElement.classList.remove('dark')")
    find("[data-action='dark-mode#toggle']").click
    assert_selector "html.dark", wait: 3
  end

  # ── Scroll position regression tests ─────────────────────────────────────

  # Regression: overflow-x-hidden on <body> with h-full disables window.scrollY
  # on iOS, so progress bar never updates and position is never saved.
  test "body element does not have overflow-hidden classes" do
    visit essay_path(@essay)
    body_class = find("body")["class"].to_s
    assert_not body_class.include?("overflow-hidden"),
      "overflow-hidden on <body> disables window scrolling on iOS"
    assert_not body_class.include?("overflow-x-hidden"),
      "overflow-x-hidden on <body> disables window scrolling on iOS"
  end

  test "progress bar updates immediately when page is scrolled" do
    @essay.update!(content: LONG_CONTENT, word_count: 5000, last_read_position: 0)
    visit essay_path(@essay)

    assert_equal 0.0, progress_bar_width, "Progress bar should start at 0"

    # Scroll 60% down and verify the window actually moved
    page.execute_script("window.scrollTo(0, document.documentElement.scrollHeight * 0.6)")
    sleep 0.5  # let scroll event fire and _updateUI run

    scroll_y = page.execute_script("return window.scrollY").to_f
    assert scroll_y > 50, "window.scrollY should be non-zero after scrollTo (got #{scroll_y})"

    assert progress_bar_width > 10.0,
      "Progress bar should be >10% after scrolling 60% down (was #{progress_bar_width})"
  end

  test "scroll position is saved to the database after navigating away" do
    @essay.update!(content: LONG_CONTENT, word_count: 5000)
    visit essay_path(@essay)

    page.execute_script("window.scrollTo(0, document.documentElement.scrollHeight * 0.6)")
    sleep 0.3  # let scroll event fire and set the pending persist

    # Navigating away triggers disconnect() which calls _persistCurrent() immediately
    visit essays_path
    sleep 0.5  # let the keepalive fetch complete

    assert @essay.reload.last_read_position > 0.1,
      "Position should be saved when navigating away (got #{@essay.last_read_position})"
  end

  test "saved scroll position is restored when returning to the essay" do
    @essay.update!(content: LONG_CONTENT, word_count: 5000, last_read_position: 0.5)
    visit essay_path(@essay)

    # _restore() retries via rAF until scrollHeight settles — give it a moment
    sleep 0.8

    scroll_y = page.execute_script("return window.scrollY").to_f
    assert scroll_y > 50,
      "Page should be scrolled to restored position (scrollY was #{scroll_y})"
  end

  test "window.scrollY is readable (not blocked by overflow restrictions)" do
    @essay.update!(content: LONG_CONTENT, word_count: 5000)
    visit essay_path(@essay)

    page.execute_script("window.scrollTo(0, 200)")
    sleep 0.2

    scroll_y = page.execute_script("return window.scrollY").to_f
    assert scroll_y >= 100,
      "window.scrollY must be non-zero after scrolling — overflow on body/html blocks this on iOS"
  end

  private

  def progress_bar_width
    bar = find("#reading-progress", visible: :any)
    style = bar["style"].to_s
    style[/width:\s*([\d.]+)%/, 1].to_f
  end
end
