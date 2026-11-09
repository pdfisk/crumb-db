source "https://rubygems.org"

ruby "~> 3.4"

gem "rails", "~> 8.0.2"
gem "pg", "~> 1.5"
gem "puma", ">= 6.0"
gem "rack-cors"

# Passwords: has_secure_password stores a bcrypt digest.
gem "bcrypt", "~> 3.1"
gem "bootsnap", require: false

# Thredded's engine needs Sprockets to boot, and in development and test it
# refuses to start without a Sass compiler. No assets are served.
gem "sprockets-rails"
gem "dartsass-sprockets"

# The forum engine (config/initializers/thredded.rb). Needs Ruby < 4.0.
gem "thredded", "~> 1.2"
gem "fiddle", "~> 1.1.8"

# json 3 refuses the quirks_mode option that Rails 8.0's JSON decoder still
# passes ("unknown keyword: quirks_mode" on every JSON request). Thredded's
# dependencies (execjs) pulled json 3 in; keep 2.x until Rails no longer needs it.
gem "json", "~> 2.10"

# Windows does not include zoneinfo files
gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  gem "dotenv-rails"
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
end
