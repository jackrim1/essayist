require "test_helper"

class RecommendationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user  = users(:one)
    @essay = essays(:one)
    sign_in @user
    GenerateRecommendationsJob.stubs(:perform_later)
  end

  # ── create ──────────────────────────────────────────────────────────────────

  test "POST create with kind=author creates recommendation and redirects" do
    assert_difference "Recommendation.count", 1 do
      post essay_recommendations_path(@essay), params: { kind: "author" }
    end

    rec = Recommendation.last
    assert_equal "author", rec.kind
    assert rec.pending?
    assert_redirected_to recommendation_path(rec)
  end

  test "POST create with kind=subject creates recommendation" do
    post essay_recommendations_path(@essay), params: { kind: "subject" }
    assert_equal "subject", Recommendation.last.kind
  end

  test "POST create enqueues generate job" do
    GenerateRecommendationsJob.expects(:perform_later).once
    post essay_recommendations_path(@essay), params: { kind: "author" }
  end

  test "POST create with invalid kind redirects to essay with alert" do
    assert_no_difference "Recommendation.count" do
      post essay_recommendations_path(@essay), params: { kind: "bogus" }
    end
    assert_redirected_to essay_path(@essay)
  end

  test "POST create requires authentication" do
    sign_out @user
    post essay_recommendations_path(@essay), params: { kind: "author" }
    assert_redirected_to new_user_session_path
  end

  test "POST create cannot create recommendation for another user's essay" do
    essay2 = Essay.create!(
      user:  User.create!(email: "other@example.com", password: "password123"),
      title: "Other Essay"
    )
    post essay_recommendations_path(essay2), params: { kind: "author" }
    assert_response :not_found
  end

  # ── show ────────────────────────────────────────────────────────────────────

  test "GET show renders pending recommendation" do
    rec = recommendations(:author_pending)
    get recommendation_path(rec)
    assert_response :success
    assert_select "#recommendation-content"
  end

  test "GET show renders complete recommendation with results" do
    rec = recommendations(:subject_complete)
    get recommendation_path(rec)
    assert_response :success
    assert_select "ol"
  end

  test "GET show renders failed recommendation without raising" do
    rec = recommendations(:author_failed)
    get recommendation_path(rec)
    assert_response :success
  end

  test "GET show displays error message on failed recommendation" do
    rec = recommendations(:author_failed)
    get recommendation_path(rec)
    assert_select "[id='recommendation-content']"
    assert_match(/RecommendationPrompt/, response.body)
  end

  test "GET show requires authentication" do
    sign_out @user
    get recommendation_path(recommendations(:author_pending))
    assert_redirected_to new_user_session_path
  end

  test "GET show cannot view another user's recommendation" do
    other_user  = User.create!(email: "stranger@example.com", password: "password123")
    other_essay = Essay.create!(user: other_user, title: "Strangers Essay")
    other_rec   = Recommendation.create!(essay: other_essay, user: other_user, kind: "author", status: :pending)

    get recommendation_path(other_rec)
    assert_response :not_found
  end
end
