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
  resource :session, only: %i[show create destroy]

  # The forum as JSON, for the IDE's Forum window (ForumApiController,
  # ForumModerationController). The forum has no web pages of its own.
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
