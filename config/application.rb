require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "action_mailer/railtie"
require "active_job/railtie"
require "sprockets/railtie"

Bundler.require(*Rails.groups)

module Server
  class Application < Rails::Application
    config.load_defaults 8.0
    config.autoload_lib(ignore: %w[assets tasks])

    # The API is JSON only: its controllers (ApiController) answer bearer-token
    # requests and ignore cookies. The forum (ApplicationController and
    # Thredded) is HTML pages with a cookie session, on its own host, so the
    # middleware an API-only app leaves out is added back for it.
    config.api_only = true

    # The forum's address: FORUM_HOST, else forum.fastblips.com in production
    # and forum.localhost elsewhere (browsers send *.localhost to this machine).
    config.x.forum_host = ENV.fetch("FORUM_HOST") do
      Rails.env.production? ? "forum.fastblips.com" : "forum.localhost"
    end

    # No cookie domain, so the cookie belongs to the forum host alone.
    config.session_store :cookie_store, key: "_fastblips_forum", same_site: :lax,
                                        secure: Rails.env.production?, expire_after: 30.days
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use config.session_store, config.session_options
    config.middleware.use ActionDispatch::Flash
    config.middleware.use Rack::MethodOverride
  end
end
