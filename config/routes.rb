Rails.application.routes.draw do
  # Health check: 200 if the app boots, 500 otherwise.
  get "up" => "rails/health#show", as: :rails_health_check

  resources :python_sources
  resources :basic_sources
end
