# Origins allowed to call the API from a browser: the site, local development
# and the desktop app (Electron serves its page from app://fastblips). Setting
# CORS_ORIGINS (comma-separated) replaces this whole list, so a value set on
# Heroku must include app://fastblips too.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*ENV.fetch("CORS_ORIGINS", "http://localhost:8080,https://fastblips.com,https://www.fastblips.com,app://fastblips").split(",").map(&:strip))

    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ]
  end
end
