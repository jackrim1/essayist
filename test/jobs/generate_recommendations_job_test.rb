require "test_helper"

class GenerateRecommendationsJobTest < ActiveSupport::TestCase
  # Expose private helpers for unit testing
  class TestableJob < GenerateRecommendationsJob
    public :library_keys, :already_owned?, :normalise, :significant_words
  end

  setup do
    @job          = TestableJob.new
    @user         = users(:one)
    @essay        = essays(:one)   # "On the Shortness of Life" by Seneca
    @recommendation = recommendations(:author_pending)
  end

  # ── library_keys ────────────────────────────────────────────────────────────

  test "library_keys returns normalised set of title+author strings" do
    keys = @job.library_keys(@user)
    assert_kind_of Set, keys
    assert keys.any? { |k| k.include?("shortness") }
  end

  # ── already_owned? ──────────────────────────────────────────────────────────

  test "already_owned? returns true for exact title match" do
    owned = @job.library_keys(@user)
    candidate = { "title" => "On the Shortness of Life", "author" => "Seneca" }
    assert @job.already_owned?(candidate, owned)
  end

  test "already_owned? returns true when article differs" do
    owned = @job.library_keys(@user)
    # "The Shortness of Life" vs "On the Shortness of Life" — significant words overlap heavily
    candidate = { "title" => "The Shortness of Life", "author" => "Seneca" }
    assert @job.already_owned?(candidate, owned)
  end

  test "already_owned? returns false for unrelated essay" do
    owned = @job.library_keys(@user)
    candidate = { "title" => "Self-Reliance", "author" => "Ralph Waldo Emerson" }
    assert_not @job.already_owned?(candidate, owned)
  end

  test "already_owned? returns false with only one word overlap" do
    owned = @job.library_keys(@user)
    # Only "life" overlaps — below 2 word minimum
    candidate = { "title" => "Life in the Woods", "author" => "Henry Thoreau" }
    assert_not @job.already_owned?(candidate, owned)
  end

  test "already_owned? is case insensitive" do
    owned = @job.library_keys(@user)
    candidate = { "title" => "ON THE SHORTNESS OF LIFE", "author" => "SENECA" }
    assert @job.already_owned?(candidate, owned)
  end

  # ── normalise ───────────────────────────────────────────────────────────────

  test "normalise strips punctuation and lowercases" do
    assert_equal "on the shortness of life", @job.normalise("On the Shortness of Life!")
  end

  test "normalise squishes extra whitespace" do
    assert_equal "hello world", @job.normalise("hello   world")
  end

  # ── integration: filters owned essays from results ──────────────────────────

  test "job skips results already in library" do
    GenerateRecommendationsJob.stubs(:perform_later)
    VerifyRecommendationUrlJob.stubs(:perform_later)
    Turbo::StreamsChannel.stubs(:broadcast_replace_to)

    ten_results = Array.new(10) do |i|
      { "title" => "Essay #{i + 1}", "author" => "Author #{i + 1}",
        "description" => "Desc.", "url" => nil, "url_type" => nil }
    end
    # Inject the already-owned essay as the last candidate
    ten_results << { "title" => "On the Shortness of Life", "author" => "Seneca",
                     "description" => "Dup.", "url" => nil, "url_type" => nil }

    RecommendationService.stubs(:call).returns(ten_results)

    GenerateRecommendationsJob.new.perform(@recommendation.id)

    titles = @recommendation.results.reload.map(&:title)
    assert_not_includes titles, "On the Shortness of Life"
    assert_equal 10, titles.size  # 10 unique non-owned kept
  end

  test "job marks recommendation failed when prompt row is missing" do
    RecommendationPrompt.delete_all
    Turbo::StreamsChannel.stubs(:broadcast_replace_to)

    GenerateRecommendationsJob.new.perform(@recommendation.id)

    assert @recommendation.reload.failed?
    assert_match(/RecommendationPrompt/, @recommendation.error_message)
  end

  test "job does not raise when broadcast fails inside rescue block" do
    RecommendationPrompt.delete_all
    Turbo::StreamsChannel.stubs(:broadcast_replace_to).raises(ArgumentError, "No unique index found for id")

    assert_nothing_raised { GenerateRecommendationsJob.new.perform(@recommendation.id) }
    assert @recommendation.reload.failed?
  end

  test "job clears previous results before recreating on retry" do
    VerifyRecommendationUrlJob.stubs(:perform_later)
    Turbo::StreamsChannel.stubs(:broadcast_replace_to)

    two_results = [
      { "title" => "Essay A", "author" => "Author A", "description" => "D", "url" => nil, "url_type" => nil },
      { "title" => "Essay B", "author" => "Author B", "description" => "D", "url" => nil, "url_type" => nil }
    ]
    RecommendationService.stubs(:call).returns(two_results)

    # Run twice (simulating a retry)
    GenerateRecommendationsJob.new.perform(@recommendation.id)
    @recommendation.update!(status: :pending)  # reset for retry
    GenerateRecommendationsJob.new.perform(@recommendation.id)

    assert_equal 2, @recommendation.results.reload.count
  end

  test "job renumbers positions after filtering" do
    GenerateRecommendationsJob.stubs(:perform_later)
    VerifyRecommendationUrlJob.stubs(:perform_later)
    Turbo::StreamsChannel.stubs(:broadcast_replace_to)

    results = [
      { "title" => "On the Shortness of Life", "author" => "Seneca", "description" => "Dup.", "url" => nil, "url_type" => nil },
      { "title" => "Self-Reliance", "author" => "Emerson", "description" => "Good one.", "url" => nil, "url_type" => nil },
      { "title" => "Walking", "author" => "Thoreau", "description" => "Nature.", "url" => nil, "url_type" => nil }
    ]
    RecommendationService.stubs(:call).returns(results)

    GenerateRecommendationsJob.new.perform(@recommendation.id)

    saved = @recommendation.results.reload.order(:position)
    assert_equal 2, saved.size
    assert_equal 1, saved.first.position
    assert_equal 2, saved.second.position
  end
end
