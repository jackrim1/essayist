require_relative "boot"
require "rails/all"

Bundler.require(*Rails.groups)

module Essayist
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])
    config.time_zone = "UTC"
    config.active_storage.variant_processor = :vips
    # Use solid_queue in production; :async in dev/test (no extra tables needed)
    config.active_job.queue_adapter = Rails.env.production? ? :solid_queue : :async
    config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST", "localhost:3000") }
  end
end
