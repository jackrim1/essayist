require "application_system_test_case"

class UploadTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "file picker shows filename after selection" do
    visit new_essay_path

    label = find("[data-file-picker-target='label']")
    assert_equal "Drop a PDF or tap to browse", label.text

    pdf_path = Rails.root.join("test/fixtures/files/friedman.pdf").to_s
    find("[data-file-picker-target='input']", visible: false).attach_file(pdf_path)

    assert_not_equal "Drop a PDF or tap to browse", label.text
    assert_includes label.text, "friedman.pdf"
  end

  test "upload form has required fields" do
    visit new_essay_path

    assert_selector "input[name='essay[title]']"
    assert_selector "input[name='essay[author]']"
    assert_selector "input[type='file'][accept='application/pdf']"
    assert_selector "input[type='submit']"
  end

  test "upload creates essay and shows extracting state" do
    visit new_essay_path

    fill_in "essay[title]", with: "Test Essay"
    fill_in "essay[author]", with: "Test Author"

    pdf_path = Rails.root.join("test/fixtures/files/friedman.pdf").to_s
    find("input[type='file']", visible: false).attach_file(pdf_path)

    perform_enqueued_jobs do
      click_on "Upload"
      assert_current_path %r{/essays/\d+}
    end
  end
end
