require "test_helper"

class PwaControllerTest < ActionDispatch::IntegrationTest
  test "GET manifest returns JSON" do
    get pwa_manifest_path
    assert_response :success
    assert_equal "application/json", response.content_type.split(";").first
    body = JSON.parse(response.body)
    assert_equal "Essayist", body["name"]
  end

  test "GET service-worker returns JS without CSRF error" do
    # Browsers fetch service workers cross-origin, which previously raised
    # ActionController::InvalidCrossOriginRequest before the CSRF skip was added.
    get service_worker_path, headers: { "HTTP_SEC_FETCH_SITE" => "cross-site" }
    assert_response :success
    assert_equal "application/javascript", response.content_type.split(";").first
  end

  test "GET service-worker is accessible without authentication" do
    get service_worker_path
    assert_response :success
  end
end
