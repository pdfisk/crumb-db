ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Helpers for the API tests: users, tokens and JSON.
module ApiHelpers
  PASSWORD = "correct horse battery".freeze

  def make_user(name, **attrs)
    User.create!({ name: name, password: PASSWORD }.merge(attrs))
  end

  def bearer(user)
    { "Authorization" => "Bearer #{ApiToken.issue(user).last}" }
  end

  def make_script(owner, name, **attrs)
    Script.create!({ name: name, language: "basic", content: "Print 1", owner: owner }.merge(attrs))
  end

  # Runs the block with these users as administrators.
  def with_admins(*names)
    was = ENV["ADMIN_USERS"]
    ENV["ADMIN_USERS"] = names.join(",")
    yield
  ensure
    ENV["ADMIN_USERS"] = was
  end

  def names(list)
    list.map { |r| r["name"] }.sort
  end
end

ActionDispatch::IntegrationTest.include ApiHelpers
