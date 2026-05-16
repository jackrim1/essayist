require "application_system_test_case"

class HighlightTest < ApplicationSystemTestCase
  ESSAY_TEXT = "It is not that we have a short time to live, but that we waste a great deal of it."

  setup do
    @user  = users(:one)
    @essay = essays(:one)
    @essay.highlights.destroy_all
    @essay.update!(content: "<p class=\"prose-page\">#{ESSAY_TEXT}</p>")
    sign_in @user
  end

  # ── Toolbar appearance ─────────────────────────────────────────────────────

  test "selecting text shows the highlight toolbar" do
    visit essay_path(@essay)
    select_text_in_essay
    assert_selector "#highlight-toolbar:not(.hidden)", visible: :any
  end

  test "toolbar is hidden before any selection" do
    visit essay_path(@essay)
    assert_selector "#highlight-toolbar.hidden", visible: :any
  end

  # ── Colour swatch regression ───────────────────────────────────────────────

  test "clicking a colour swatch keeps the toolbar visible" do
    visit essay_path(@essay)
    select_text_in_essay
    find("[data-color='green']").click
    assert_selector "button", text: "Save", wait: 1
  end

  test "selected colour is applied to the saved highlight sidebar card" do
    visit essay_path(@essay)
    select_text_in_essay
    find("[data-color='blue']").click
    find("button", text: "Save").click

    # CSS validation: sidebar card has blue background class
    assert_selector ".bg-blue-50", wait: 3
  end

  # ── SPEC 1: Body mark appears immediately, scroll position unchanged ────────

  test "saving a highlight immediately marks the text in the essay body" do
    visit essay_path(@essay)
    select_text_in_essay
    find("button", text: "Save").click

    # CSS validation: <mark> with hl-id appears inside the article
    assert_selector "article mark[data-hl-id]", wait: 3
  end

  test "body mark has the correct highlight colour as inline background style" do
    visit essay_path(@essay)
    select_text_in_essay
    find("[data-color='green']").click
    find("button", text: "Save").click

    # CSS validation: mark carries the green inline background-color
    assert_selector "article mark[data-hl-id]", wait: 3
    bg = page.evaluate_script("document.querySelector('article mark[data-hl-id]').style.backgroundColor")
    assert_match %r{rgba?\(134}, bg
  end

  test "scroll position does not change after saving a highlight" do
    # Ensure there is enough content to scroll
    long_content = ("<p class=\"prose-page\">#{ESSAY_TEXT}</p>\n" * 30)
    @essay.update!(content: long_content)

    visit essay_path(@essay)

    # Scroll down so we're not at the top
    page.execute_script("document.getElementById('reader-content').scrollTop = 300")
    scroll_before = page.evaluate_script("document.getElementById('reader-content').scrollTop")

    select_text_in_essay
    find("button", text: "Save").click
    assert_selector "article mark[data-hl-id]", wait: 3

    scroll_after = page.evaluate_script("document.getElementById('reader-content').scrollTop")
    assert_equal scroll_before, scroll_after, "scroll position must not change after saving highlight"
  end

  test "toolbar hides after save and highlight appears in sidebar" do
    visit essay_path(@essay)
    select_text_in_essay
    find("button", text: "Save").click

    assert_selector "#highlight-toolbar.hidden", visible: :any, wait: 2
    assert_selector "#highlights-list li", wait: 3
  end

  test "anchor is saved so mark reappears on next page visit" do
    visit essay_path(@essay)
    select_text_in_essay
    find("button", text: "Save").click
    assert_selector "article mark[data-hl-id]", wait: 3

    # Reload the page — mark must still be there (requires anchor to be saved)
    visit essay_path(@essay)
    assert_selector "article mark[data-hl-id]", wait: 3
  end

  test "existing highlights are marked in the text on page load" do
    Highlight.create!(
      essay: @essay, user: @user,
      content: "It is not that we",
      color: "green",
      anchor: { startPara: 0, startOffset: 0, endPara: 0, endOffset: 18 }
    )
    visit essay_path(@essay)
    # CSS validation: mark present with correct data attribute
    assert_selector "article mark[data-hl-id]", wait: 3
  end

  test "deleting a highlight removes its mark from the essay text" do
    highlight = Highlight.create!(
      essay: @essay, user: @user,
      content: "It is not that we",
      color: "yellow",
      anchor: { startPara: 0, startOffset: 0, endPara: 0, endOffset: 18 }
    )

    visit essay_path(@essay)
    assert_selector "article mark[data-hl-id='#{highlight.id}']", wait: 3

    accept_confirm do
      find("#highlight_#{highlight.id} form[action*='highlight'] button[type='submit']",
           visible: :any).click
    end

    assert_no_selector "article mark[data-hl-id='#{highlight.id}']", wait: 3
  end

  test "saving a highlight prepends it to the sidebar list" do
    Highlight.create!(essay: @essay, user: @user, content: "short time", color: "yellow", anchor: {})

    visit essay_path(@essay)
    assert_selector "#highlights-list li", count: 1

    select_text_in_essay
    find("button", text: "Save").click

    assert_selector "#highlights-list li", count: 2, wait: 3
  end

  test "saving the first highlight removes the empty state hint" do
    visit essay_path(@essay)
    assert_text "Select text to save a highlight."

    select_text_in_essay
    find("button", text: "Save").click

    assert_selector "#highlights-list li", wait: 3
    assert_no_selector "#highlights-empty", wait: 1
  end

  test "deleting a highlight removes it from the sidebar" do
    highlight = Highlight.create!(
      essay: @essay, user: @user,
      content: "short time to live", color: "yellow", anchor: {}
    )

    visit essay_path(@essay)
    assert_selector "#highlight_#{highlight.id}"

    accept_confirm do
      find("#highlight_#{highlight.id} form[action*='highlight'] button[type='submit']",
           visible: :any).click
    end

    assert_no_selector "#highlight_#{highlight.id}", wait: 3
  end

  # ── Regression: toolbar survives post-drag click on content ────────────────

  test "toolbar survives the click that fires after completing a mouse-drag selection" do
    visit essay_path(@essay)
    select_text_in_essay

    page.execute_script(<<~JS)
      const para = document.querySelector('[data-controller*="highlight"] p.prose-page');
      para.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
    JS

    assert_selector "#highlight-toolbar:not(.hidden)", visible: :any, wait: 1
  end

  test "clicking outside the toolbar dismisses it" do
    visit essay_path(@essay)
    select_text_in_essay
    find("article > header").click
    assert_selector "#highlight-toolbar.hidden", visible: :any, wait: 1
  end

  # ── SPEC 2: Bookmark icon + highlight count on essay index cards ────────────

  test "essay card on index shows bookmark icon and highlight count" do
    Highlight.create!(essay: @essay, user: @user, content: "short time", color: "yellow", anchor: {})

    visit essays_path

    within "##{dom_id(@essay)}" do
      # CSS validation: .highlight-count span is present
      assert_selector ".highlight-count"
      assert_selector ".highlight-count svg"
      assert_text "1"
    end
  end

  test "bookmark count reflects actual highlight count" do
    3.times { |i| Highlight.create!(essay: @essay, user: @user, content: "text #{i}", color: "yellow", anchor: {}) }

    visit essays_path

    within "##{dom_id(@essay)}" do
      assert_selector ".highlight-count"
      assert_text "3"
    end
  end

  test "essay card shows count 0 and greyed icon when no highlights" do
    visit essays_path

    within "##{dom_id(@essay)}" do
      assert_selector ".highlight-count"
      assert_text "0"
      # CSS validation: zero-count span exists (greyed via text-zinc-300)
      count_classes = find(".highlight-count")[:class]
      assert_match(/text-zinc/, count_classes)
    end
  end

  # ── SPEC 3: Highlights panel on index page ─────────────────────────────────

  test "highlights panel appears on index when highlights exist" do
    Highlight.create!(essay: @essay, user: @user, content: "It is not that we have a short time", color: "yellow", anchor: {})

    visit essays_path

    assert_selector "#highlights-panel"
    assert_selector "#highlights-panel .highlight-item"
  end

  test "highlights panel shows truncated text (≤50 chars)" do
    long_content = "A" * 80
    Highlight.create!(essay: @essay, user: @user, content: long_content, color: "yellow", anchor: {})

    visit essays_path

    within "#highlights-panel" do
      text = find(".highlight-item p:first-child").text
      assert text.length <= 53, "truncated text should be ≤50 chars (plus ellipsis): got #{text.length}"
    end
  end

  test "highlights panel shows essay title and author beneath each item" do
    Highlight.create!(essay: @essay, user: @user, content: "It is not that we", color: "yellow", anchor: {})

    visit essays_path

    within "#highlights-panel .highlight-item" do
      # CSS validation: smaller italic text with title + author
      assert_selector "p.italic, p em", visible: :any
      assert_text @essay.title
      assert_text @essay.author_name
    end
  end

  test "clicking a highlights panel item navigates to essay show page" do
    highlight = Highlight.create!(
      essay: @essay, user: @user,
      content: "It is not that we",
      color: "yellow",
      anchor: { startPara: 0, startOffset: 0, endPara: 0, endOffset: 18 }
    )

    visit essays_path
    within "#highlights-panel" do
      find(".highlight-item a").click
    end

    assert_current_path essay_path(@essay, highlight: highlight.id)
  end

  test "navigating to essay via highlights panel link scrolls to the mark" do
    highlight = Highlight.create!(
      essay: @essay, user: @user,
      content: "It is not that we",
      color: "yellow",
      anchor: { startPara: 0, startOffset: 0, endPara: 0, endOffset: 18 }
    )

    visit essay_path(@essay, highlight: highlight.id)

    # CSS validation: the mark with the highlight ID is in the DOM
    assert_selector "article mark[data-hl-id='#{highlight.id}']", wait: 3

    # The mark should be visible (scrolled into view)
    mark_visible = page.evaluate_script(<<~JS)
      (() => {
        const mark = document.querySelector("mark[data-hl-id='#{highlight.id}']");
        if (!mark) return false;
        const rect = mark.getBoundingClientRect();
        return rect.top >= 0 && rect.bottom <= window.innerHeight;
      })()
    JS
    assert mark_visible, "highlight mark should be scrolled into the viewport"
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  private

  def select_text_in_essay
    page.execute_script(<<~JS)
      const para = document.querySelector('[data-controller*="highlight"] p.prose-page');
      if (!para || !para.firstChild) return;
      const range = document.createRange();
      range.setStart(para.firstChild, 0);
      range.setEnd(para.firstChild, Math.min(20, para.firstChild.length));
      window.getSelection().removeAllRanges();
      window.getSelection().addRange(range);
      document.dispatchEvent(new Event('selectionchange'));
    JS
    assert_selector "#highlight-toolbar:not(.hidden)", visible: :any, wait: 3
  end
end
