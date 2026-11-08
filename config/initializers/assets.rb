# Assets precompiled besides those manifest.js links.
#
# The forum's script (app/assets/javascripts/application.js, which requires
# Thredded's): manifest.js links it, but Sprockets keeps only the stylesheet
# link from that file here, so the layout's javascript_include_tag failed with
# "application.js was not declared to be precompiled". Declaring it directly
# fixes that in every environment, including assets:precompile on Heroku.
Rails.application.config.assets.precompile += %w[application.js]
