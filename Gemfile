source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "propshaft"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "jbuilder"
gem "tzinfo-data", platforms: %i[windows jruby]

# Solid adapters (Rails 8 defaults)
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

gem "bootsnap", require: false
gem "image_processing", "~> 1.2"

# Auth
gem "devise"

# AI + PDF text extraction
gem "anthropic"
gem "pdftotext"

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "dotenv-rails"
end

group :development do
  gem "web-console"
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
  gem "shoulda-matchers"
  gem "mocha"
end
