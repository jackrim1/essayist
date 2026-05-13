class ApplicationJob < ActiveJob::Base
  # Retry transient failures twice before giving up
  retry_on StandardError, wait: :polynomially_longer, attempts: 3
end
