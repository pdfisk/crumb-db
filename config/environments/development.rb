require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Sign-in is not needed from this machine (see Authentication). Set
  # LOCAL_REQUIRE_LOGIN=1 to test the real sign-in flow locally.
  config.x.local_trust = ENV["LOCAL_REQUIRE_LOGIN"].to_s != "1"
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true
  config.cache_store = :memory_store
  config.active_support.deprecation = :log
  config.active_record.migration_error = :page_load
  config.active_record.verbose_query_logs = true
  config.action_controller.raise_on_missing_callback_actions = true
end
