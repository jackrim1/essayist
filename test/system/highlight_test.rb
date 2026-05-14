require "application_system_test_case"

class HighlightTest < ApplicationSystemTestCase
  setup do
    @user  = users(:one)
    @essay = essays(:one)
    @essay.update!(content: '<p class="prose-page">It is not that we have a short time to live, but that we waste a great deal of it.</p>')
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

  # ── Regression: colour swatch click must not dismiss the toolbar ───────────

  test "clicking a colour swatch keeps the toolbar visible" do
    visit essay_path(@essay)
    select_text_in_essay

    find("[data-color='green']").click

    # Toolbar must still be open so the user can press Save
    assert_selector "button", text: "Save", wait: 1
  end

  test "selected colour is applied to the saved highlight" do
    @essay.highlights.destroy_all

    visit essay_path(@essay)
    select_text_in_essay

    find("[data-color='blue']").click
    find("button", text: "Save").click

    assert_selector ".bg-blue-50", wait: 3
  end

  test "toolbar hides and highlight appears after save" do
    @essay.highlights.destroy_all

    visit essay_path(@essay)
    select_text_in_essay

    find("button", text: "Save").click

    # Toolbar fades out (via selectionchange timer) and highlight appears
    assert_selector "#highlight-toolbar.hidden", visible: :any, wait: 2
    assert_selector "#highlights-list li", wait: 3
  end

  # ── Text marking ───────────────────────────────────────────────────────────

  test "saving a highlight marks the selected text in the essay" do
    @essay.highlights.destroy_all

    visit essay_path(@essay)
    select_text_in_essay

    find("button", text: "Save").click

    # A <mark> element must appear inside the essay article wrapping the text
    assert_selector "article mark[data-hl-id]", wait: 3
  end

  test "existing highlights are marked in the text on page load" do
    @essay.highlights.destroy_all
    Highlight.create!(
      essay: @essay, user: @user,
      content: "It is not that we",
      color: "green",
      anchor: { startPara: 0, startOffset: 0, endPara: 0, endOffset: 18 }
    )

    visit essay_path(@essay)

    assert_selector "article mark[data-hl-id]", wait: 3
  end

  test "deleting a highlight removes its mark from the essay text" do
    @essay.highlights.destroy_all
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

  # ── Saving ─────────────────────────────────────────────────────────────────

  test "saving a highlight adds it to the sidebar" do
    @essay.highlights.destroy_all

    visit essay_path(@essay)
    select_text_in_essay

    find("button", text: "Save").click

    assert_selector "#highlights-list li", wait: 3
  end

  test "saving the first highlight removes the empty state hint" do
    @essay.highlights.destroy_all

    visit essay_path(@essay)
    assert_text "Select text to save a highlight."

    select_text_in_essay
    find("button", text: "Save").click

    # The turbo stream removes #highlights-empty and prepends the new li
    assert_selector "#highlights-list li", wait: 3
    assert_no_selector "#highlights-empty", wait: 1
  end

  test "saving a second highlight prepends to the list" do
    @essay.highlights.destroy_all
    Highlight.create!(essay: @essay, user: @user, content: "short time", color: "yellow", anchor: {})

    visit essay_path(@essay)
    assert_selector "#highlights-list li", count: 1

    select_text_in_essay
    find("button", text: "Save").click

    assert_selector "#highlights-list li", count: 2, wait: 3
  end

  # ── Deletion ───────────────────────────────────────────────────────────────

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

  # ── Regression: toolbar must survive post-drag click on content ───────────
  #
  # Real bug: after a mouse-drag selection the browser fires a click event on
  # the content paragraph (as part of completing the gesture). _onDocClick sees
  # that paragraph is not inside the toolbar and immediately hides it — before
  # the user can pick a colour or press Save.
  # Programmatic addRange() never fires that click, so the other tests miss it.

  test "toolbar survives the click that fires after completing a mouse-drag selection" do
    visit essay_path(@essay)
    select_text_in_essay  # toolbar is now visible

    # Simulate the bare click that the browser fires on the paragraph when
    # the user releases the mouse after dragging to select text.
    page.execute_script(<<~JS)
      const para = document.querySelector('[data-controller*="highlight"] p.prose-page');
      para.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
    JS

    assert_selector "#highlight-toolbar:not(.hidden)", visible: :any, wait: 1
  end

  # ── Dismissal ──────────────────────────────────────────────────────────────

  test "clicking outside the toolbar dismisses it" do
    visit essay_path(@essay)
    select_text_in_essay

    # Click the article's own header (title area) — inside main but outside the toolbar
    find("article > header").click

    assert_selector "#highlight-toolbar.hidden", visible: :any, wait: 1
  end

  # ── Helpers ────────────────────────────────────────────────────────────────

  private

  # Selects the first 20 chars of the prose paragraph, explicitly re-dispatches
  # selectionchange (headless Chrome may defer the native event), then waits for
  # the Stimulus controller to show the toolbar before returning.
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
    # Hard synchronisation: don't proceed until the Stimulus controller has
    # processed the selection and made the toolbar visible.
    assert_selector "#highlight-toolbar:not(.hidden)", visible: :any, wait: 3
  end
end
