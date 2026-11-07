# Allow browser clients to call the API. Set CORS_ORIGINS to a
# comma-separated list (e.g. "https://myapp.com,http://localhost:5173")
# to restrict it; defaults to any origin.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*ENV.fetch("CORS_ORIGINS", "http://localhost:8080,https://fastblips.com,https://www.fastblips.com,app://fastblips").split(",").map(&:strip))

    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ]
  end
end
