require "test_helper"

class PositionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user  = users(:one)
    @essay = essays(:one)
    sign_in @user
  end

  test "PATCH with JSON body updates last_read_position and returns 204" do
    patch essay_position_path(@essay),
      params: { position: 0.42 }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :no_content
    assert_in_delta 0.42, @essay.reload.last_read_position, 0.001
  end

  test "clamps position to 0..1" do
    patch essay_position_path(@essay),
      params: { position: 1.5 }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :no_content
    assert_equal 1.0, @essay.reload.last_read_position
  end

  # The JS controller updates the progress bar immediately on every scroll
  # event but only POSTs to the server every 2 s (throttled). This means
  # rapid saves can arrive in quick succession — the endpoint must be
  # idempotent and last-write-wins.
  test "successive saves overwrite with the latest value (last-write-wins)" do
    [0.1, 0.3, 0.55, 0.7].each do |pos|
      patch essay_position_path(@essay),
        params: { position: pos }.to_json,
        headers: { "Content-Type" => "application/json" }
      assert_response :no_content
    end

    assert_in_delta 0.7, @essay.reload.last_read_position, 0.001
  end

  test "saved position is reflected in reading_percent on essay" do
    patch essay_position_path(@essay),
      params: { position: 0.63 }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_equal 63, @essay.reload.reading_percent
  end

  test "position 0 clears reading progress" do
    @essay.update_column(:last_read_position, 0.8)

    patch essay_position_path(@essay),
      params: { position: 0.0 }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_equal 0.0, @essay.reload.last_read_position
  end

  test "redirects to sign-in when not authenticated" do
    sign_out @user
    patch essay_position_path(@essay),
      params: { position: 0.5 }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :redirect
  end

  test "returns 404 for an essay belonging to another user" do
    other_user  = User.create!(email: "other@example.com", password: "password123")
    other_essay = other_user.essays.create!(title: "Other Essay", content: "<p>x</p>", word_count: 1)

    patch essay_position_path(other_essay),
      params: { position: 0.5 }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :not_found
  end
end
