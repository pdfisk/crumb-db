# Heroku sets PORT and WEB_CONCURRENCY.
threads_count = ENV.fetch("RAILS_MAX_THREADS", 5)
threads threads_count, threads_count

port ENV.fetch("PORT", 3000)

workers ENV.fetch("WEB_CONCURRENCY", 0).to_i unless Gem.win_platform? # Puma has no cluster mode on Windows
preload_app!

plugin :tmp_restart
pidfile ENV["PIDFILE"] if ENV["PIDFILE"]
