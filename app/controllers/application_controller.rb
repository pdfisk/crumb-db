# Not used by the app: every controller is an ApiController.
#
# It exists because Thredded's controllers inherit from ::ApplicationController
# (Thredded::ApplicationController < ::ApplicationController) and are loaded
# with the rest of the engine, even though no route leads to them: the forum's
# interface is the IDE, through ForumApiController.
class ApplicationController < ActionController::Base
end
