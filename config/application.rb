require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
# Thredded (the forum's models, used by the JSON forum API) is a Rails engine
# whose classes need these to load: views and mailers, jobs (it notifies
# followers after a post), and Sprockets (its engine registers its assets).
# The app itself serves no pages, mail or assets.
require "action_view/railtie"
require "action_mailer/railtie"
require "active_job/railtie"
require "sprockets/railtie"

Bundler.require(*Rails.groups)

module Server
  class Application < Rails::Application
    config.load_defaults 8.0
    config.autoload_lib(ignore: %w[assets tasks])

    # JSON only: every controller is an ApiController (bearer tokens, no
    # cookies or sessions). The forum's interface is the IDE's Forum window,
    # which uses the JSON forum API (ForumApiController).
    config.api_only = true

    # Thredded registers its stylesheets and scripts to be precompiled; no page
    # uses them, so assets:precompile (run on every Heroku deploy) skips them.
    config.after_initialize do |app|
      app.config.assets.precompile.delete("thredded_manifest.js")
    end
  end
end
