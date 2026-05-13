require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [390, 844]  # iPhone 14 viewport

  include Devise::Test::IntegrationHelpers
end
