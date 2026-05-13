max_threads_count = ENV.fetch("RAILS_MAX_THREADS", 3)
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

worker_timeout 3600 if ENV.fetch("RAILS_ENV", "development") == "development"

port        ENV.fetch("PORT", 3000)
environment ENV.fetch("RAILS_ENV", "development")

# Single process in dev; cluster mode (workers > 0) in production
workers ENV.fetch("WEB_CONCURRENCY", 0)

plugin :tmp_restart
