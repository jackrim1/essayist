require "application_system_test_case"

class ReadingTest < ApplicationSystemTestCase
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
    @essay.update!(content: "<p class=\"prose-page\">Hello world</p>")
    visit essay_path(@essay)
    assert_text "Hello world"
  end

  # Progress bar is a 2px-tall element — check it's in the DOM, not its visibility.
  test "reader has progress bar" do
    visit essay_path(@essay)
    assert_selector "#reading-progress", visible: :any
  end

  test "reader settings drawer opens" do
    visit essay_path(@essay)
    find("[data-action='reader-settings#openDrawer']").click
    assert_text "Text size"
    assert_text "View mode"
  end

  # Requires test/fixtures/files/sample.pdf — add any real PDF before running.
  test "uploading a PDF shows the essay in the library" do
    skip "add test/fixtures/files/sample.pdf to run this test" unless
      File.exist?(Rails.root.join("test/fixtures/files/sample.pdf"))

    visit new_essay_path
    fill_in "Title",  with: "Test Essay"
    fill_in "Author", with: "Test Author"
    attach_file "PDF File", Rails.root.join("test/fixtures/files/sample.pdf")
    click_on "Upload"
    assert_text "Essay uploaded"
    assert_text "Test Essay"
  end

  test "dark mode toggle on library page" do
    visit essays_path
    # Start in light mode (clear any stored preference)
    page.execute_script("localStorage.removeItem('essayist:theme'); document.documentElement.classList.remove('dark')")
    find("[data-action='dark-mode#toggle']").click
    # Capybara waits up to Capybara.default_max_wait_time for the selector
    assert_selector "html.dark", wait: 3
  end
end
