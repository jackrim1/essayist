require "test_helper"

class PositionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user     = users(:one)
    @essay    = essays(:one)
    @progress = essay_progresses(:one)
    sign_in @user
  end

  test "PATCH with JSON body updates last_read_position and returns 204" do
    patch essay_position_path(@essay),
      params: { position: 0.42 }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :no_content
    assert_in_delta 0.42, @progress.reload.last_read_position, 0.001
  end

  test "clamps position to 0..1" do
    patch essay_position_path(@essay),
      params: { position: 1.5 }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :no_content
    assert_equal 1.0, @progress.reload.last_read_position
  end

  test "successive saves overwrite with the latest value (last-write-wins)" do
    [0.1, 0.3, 0.55, 0.7].each do |pos|
      patch essay_position_path(@essay),
        params: { position: pos }.to_json,
        headers: { "Content-Type" => "application/json" }
      assert_response :no_content
    end

    assert_in_delta 0.7, @progress.reload.last_read_position, 0.001
  end

  test "saved position is reflected in reading_percent on progress" do
    patch essay_position_path(@essay),
      params: { position: 0.63 }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_equal 63, @progress.reload.reading_percent
  end

  test "position 0 clears reading progress" do
    patch essay_position_path(@essay),
      params: { position: 0.0 }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_equal 0.0, @progress.reload.last_read_position
  end

  test "creates progress record for a new essay (no prior reading)" do
    new_essay = Essay.create!(title: "New Essay")
    assert_difference "EssayProgress.count", 1 do
      patch essay_position_path(new_essay),
        params: { position: 0.5 }.to_json,
        headers: { "Content-Type" => "application/json" }
    end
    assert_response :no_content
    assert_in_delta 0.5, EssayProgress.last.last_read_position, 0.001
  end

  test "redirects to sign-in when not authenticated" do
    sign_out @user
    patch essay_position_path(@essay),
      params: { position: 0.5 }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :redirect
  end

  test "any authenticated user can update position for any essay" do
    other_user  = User.create!(email: "other@example.com", password: "password123")
    sign_in other_user

    patch essay_position_path(@essay),
      params: { position: 0.5 }.to_json,
      headers: { "Content-Type" => "application/json" }

    assert_response :no_content
    progress = EssayProgress.find_by(user: other_user, essay: @essay)
    assert_not_nil progress
    assert_in_delta 0.5, progress.last_read_position, 0.001
  end
end
