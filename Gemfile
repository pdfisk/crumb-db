source "https://rubygems.org"

ruby "~> 3.4"

gem "rails", "~> 8.0.2"
gem "pg", "~> 1.5"
gem "puma", ">= 6.0"
gem "rack-cors"

# Passwords: has_secure_password stores a bcrypt digest.
gem "bcrypt", "~> 3.1"
gem "bootsnap", require: false

# The forum's pages: the asset pipeline, and Sass for Thredded's stylesheets.
gem "sprockets-rails"
gem "dartsass-sprockets"

# Windows does not include zoneinfo files
gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  gem "dotenv-rails"
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
end
