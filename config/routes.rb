Rails.application.routes.draw do
  # The forum, on its own host (config.x.forum_host). These pages are HTML with
  # a cookie session; the API below answers on any host.
  constraints(host: Rails.configuration.x.forum_host) do
    get    "sign_in"  => "forum_sessions#new",     as: :forum_sign_in
    post   "sign_in"  => "forum_sessions#create"
    delete "sign_out" => "forum_sessions#destroy", as: :forum_sign_out

    # A stand-in front page until Thredded is mounted here (Phase 2).
    root "forum_home#show", as: :forum_root
  end

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
  resource :session, only: %i[show create destroy]
end
