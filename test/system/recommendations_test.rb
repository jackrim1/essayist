require "application_system_test_case"

class RecommendationsTest < ApplicationSystemTestCase
  setup do
    @user  = users(:one)
    @essay = essays(:one)
    sign_in @user
  end

  # ── Dropdown ────────────────────────────────────────────────────────────────

  test "search for similar button exists on essay show page" do
    visit essay_path(@essay)
    assert_selector "[data-controller='recommendations-dropdown']"
  end

  test "dropdown is hidden by default" do
    visit essay_path(@essay)
    assert_selector "[data-recommendations-dropdown-target='menu'].hidden", visible: :all
  end

  test "clicking search button shows dropdown options" do
    visit essay_path(@essay)
    find("[data-action='recommendations-dropdown#toggle']").click
    assert_no_selector "[data-recommendations-dropdown-target='menu'].hidden"
    assert_text "More by this author"
    assert_text "More on this subject"
  end

  test "dropdown closes when clicking outside" do
    visit essay_path(@essay)
    find("[data-action='recommendations-dropdown#toggle']").click
    assert_no_selector "[data-recommendations-dropdown-target='menu'].hidden"
    find("body").click(x: 5, y: 5)
    assert_selector "[data-recommendations-dropdown-target='menu'].hidden", visible: :all
  end

  # ── Create + spinner ─────────────────────────────────────────────────────────

  test "clicking More by author redirects to recommendation page with spinner" do
    GenerateRecommendationsJob.stubs(:perform_later)

    visit essay_path(@essay)
    find("[data-action='recommendations-dropdown#toggle']").click
    click_button "More by this author"

    assert_current_path(/\/recommendations\/\d+/)
    assert_text "Finding similar essays"
  end

  test "clicking More on this subject redirects to recommendation page with spinner" do
    GenerateRecommendationsJob.stubs(:perform_later)

    visit essay_path(@essay)
    find("[data-action='recommendations-dropdown#toggle']").click
    click_button "More on this subject"

    assert_current_path(/\/recommendations\/\d+/)
    assert_text "Finding similar essays"
  end

  # ── Results display ──────────────────────────────────────────────────────────

  test "complete recommendation shows numbered results list" do
    rec = recommendations(:subject_complete)
    visit recommendation_path(rec)

    assert_selector "ol"
    assert_text "De Brevitate Vitae"
    assert_text "Seneca"
    assert_text "A meditation on using time wisely"
  end

  test "result with verified URL shows Read directly button" do
    rec = recommendations(:subject_complete)
    visit recommendation_path(rec)

    assert_text "Read directly"
    assert_selector "a", text: "Read directly"
  end

  test "result without URL shows only Search button" do
    # result two has no URL
    rec = recommendations(:subject_complete)
    visit recommendation_path(rec)

    # There should be Search buttons (at least one per result)
    assert_selector "a", text: "Search", minimum: 1
  end

  test "result with pending verification shows checking indicator" do
    result = recommendation_results(:one)
    result.update!(url_verified: nil)

    rec = recommendations(:subject_complete)
    visit recommendation_path(rec)

    assert_text "Checking"
  end

  # ── Header navigation ────────────────────────────────────────────────────────

  test "recommendation page header links back to essay" do
    rec = recommendations(:subject_complete)
    visit recommendation_path(rec)

    find("a[href='#{essay_path(@essay)}']").click
    assert_current_path(essay_path(@essay))
  end

  test "recommendation page shows kind label in header" do
    rec = recommendations(:subject_complete)
    visit recommendation_path(rec)
    assert_text "More on this subject"
  end
end
