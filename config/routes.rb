Rails.application.routes.draw do
  # Health check: 200 if the app boots, 500 otherwise.
  get "up" => "rails/health#show", as: :rails_health_check

  resources :scripts

  # The addresses from when each language had its own table: the same
  # scripts, limited to one language (ScriptsController#fixed_language).
  resources :basic_sources, controller: "scripts", defaults: { language: "basic" }
  resources :python_sources, controller: "scripts", defaults: { language: "python" }
  resources :viewports
  resources :projects
  resources :users, only: %i[create show]
end
