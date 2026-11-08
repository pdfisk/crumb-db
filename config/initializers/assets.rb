# Assets precompiled besides those manifest.js links.
#
# The forum's script (app/assets/javascripts/application.js, which requires
# Thredded's): manifest.js links it, but Sprockets keeps only the stylesheet
# link from that file here, so the layout's javascript_include_tag failed with
# "application.js was not declared to be precompiled". Declaring it directly
# fixes that in every environment, including assets:precompile on Heroku.
Rails.application.config.assets.precompile += %w[application.js]

# On Windows, Sprockets' file cache fails with "Permission denied @
# rb_file_s_rename" when two threads (Puma's, or a test run next to a running
# server) write the same cache file: Windows won't rename over a file that is
# open. So in development and test on Windows the cache is kept in memory:
# the first page after a restart compiles the assets again (a few seconds).
# Production (Heroku, Linux) keeps the file cache.
if Gem.win_platform? && !Rails.env.production?
  Rails.application.config.assets.configure do |env|
    env.cache = Sprockets::Cache::MemoryStore.new(10_000)
  end
end
