Rails.application.routes.draw do
  # The forum, on its own host (config.x.forum_host). These pages are HTML with
  # a cookie session; the API below answers on any host.
  constraints(host: Rails.configuration.x.forum_host) do
    get    "sign_in"  => "forum_sessions#new",     as: :forum_sign_in
    post   "sign_in"  => "forum_sessions#create"
    delete "sign_out" => "forum_sessions#destroy", as: :forum_sign_out
    get    "sso"      => "forum_sessions#sso",     as: :forum_sso

    # Thredded: boards, topics, posts, moderation. Mounted last, so the
    # routes above come first.
    mount Thredded::Engine => "/"
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

  # A one-time link that opens the forum signed in (ForumHandoffsController).
  post "forum_handoff" => "forum_handoffs#create"

  # The forum as JSON, for the IDE's Forum window (ForumApiController,
  # ForumModerationController). On the API host; the forum host's "/" is Thredded.
  scope "forum", controller: "forum_api", as: "forum_api" do
    get    "",                       action: :index
    get    "boards/:board_id/topics", action: :topics
    post   "boards/:board_id/topics", action: :create_topic
    get    "topics",                 action: :search
    get    "topics/:id",             action: :show
    patch  "topics/:id",             action: :update_topic
    delete "topics/:id",             action: :destroy_topic
    post   "topics/:id/follow",      action: :follow
    delete "topics/:id/follow",      action: :unfollow
    post   "topics/:id/posts",       action: :create_post
    patch  "posts/:id",              action: :update_post
    delete "posts/:id",              action: :destroy_post
    get    "posts/:id/quote",        action: :quote
    post   "preview",                action: :preview
  end
  scope "forum/moderation", controller: "forum_moderation", as: "forum_moderation" do
    get   "pending",   action: :pending
    get   "activity",  action: :activity
    get   "history",   action: :history
    post  "posts/:id", action: :moderate_post
    get   "users",     action: :users
    patch "users/:id", action: :moderate_user
  end
end
