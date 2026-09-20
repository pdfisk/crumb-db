source "https://rubygems.org"

ruby ">= 3.2.0"

gem "rails", "~> 8.0.2"
gem "pg", "~> 1.5"
gem "puma", ">= 6.0"
gem "rack-cors"
gem "bootsnap", require: false

# Windows does not include zoneinfo files
gem "tzinfo-data", platforms: %i[windows jruby]

# Ruby 3.5+/4.0 no longer ships fiddle as a default gem; irb/reline need it on Windows
gem "fiddle", platforms: %i[windows]

group :development, :test do
  gem "dotenv-rails"
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
end
