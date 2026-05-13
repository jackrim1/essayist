require "test_helper"

class ExtractEssayTextJobTest < ActiveJob::TestCase
  include ActionDispatch::TestProcess::FixtureFile
  setup do
    @essay = essays(:one)
  end

  test "enqueues job after essay creation with file attached" do
    assert_enqueued_with(job: ExtractEssayTextJob) do
      essay = users(:one).essays.create!(
        title: "New Essay",
        original_file: fixture_file_upload("friedman.pdf", "application/pdf")
      )
      assert essay.persisted?
    end
  end

  test "does not enqueue job when no file attached" do
    assert_no_enqueued_jobs(only: ExtractEssayTextJob) do
      users(:one).essays.create!(title: "No File Essay")
    end
  end

  test "perform updates essay content and word count" do
    skip "requires ANTHROPIC_API_KEY" unless ENV["ANTHROPIC_API_KEY"].present?

    @essay.original_file.attach(
      io: File.open(Rails.root.join("test/fixtures/files/friedman.pdf")),
      filename: "friedman.pdf",
      content_type: "application/pdf"
    )

    ExtractEssayTextJob.perform_now(@essay.id)

    @essay.reload
    assert @essay.content.present?
    assert @essay.word_count > 0
    assert_includes @essay.content, "<p"
  end

  test "perform is a no-op for essay without attached file" do
    essay = essays(:one)
    essay.original_file.purge if essay.original_file.attached?

    assert_nothing_raised { ExtractEssayTextJob.perform_now(essay.id) }

    essay.reload
    assert_equal "<p class=\"prose-page\">It is not that we have a short time to live.</p>", essay.content
  end
end
