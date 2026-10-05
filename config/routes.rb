Rails.application.routes.draw do
  # Health check: 200 if the app boots, 500 otherwise.
  get "up" => "rails/health#show", as: :rails_health_check

  resources :apps

  # The addresses from when each language had its own table: the same apps,
  # limited to one language (AppsController#fixed_language).
  resources :basic_sources, controller: "apps", defaults: { language: "basic" }
  resources :python_sources, controller: "apps", defaults: { language: "python" }
  resources :viewports
end
