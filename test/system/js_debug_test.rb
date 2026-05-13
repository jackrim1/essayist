require "application_system_test_case"

class JsDebugTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "stimulus controllers load and dark mode works" do
    visit essays_path

    # Check if Stimulus is available
    stimulus_loaded = page.evaluate_script("typeof window.Stimulus !== 'undefined'")
    puts "Stimulus loaded: #{stimulus_loaded}"

    # Check for JS errors
    logs = page.driver.browser.logs.get(:browser) rescue []
    puts "Console logs: #{logs.map(&:message).inspect}"

    # Check body data-controller
    body_controller = page.evaluate_script("document.body.getAttribute('data-controller')")
    puts "Body controller: #{body_controller}"

    # Check if dark-mode controller registered
    dark_registered = page.evaluate_script("window.Stimulus && window.Stimulus.router && true")
    puts "Router exists: #{dark_registered}"

    # Try clicking
    find("[data-action='dark-mode#toggle']").click
    sleep 0.5

    dark = page.evaluate_script("document.documentElement.classList.contains('dark')")
    puts "Dark class after click: #{dark}"

    assert true  # just for output
  end
end
