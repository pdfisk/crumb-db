# The base of the JSON API's controllers: bearer-token sign-in (Authentication),
# JSON errors, no cookies or CSRF. (ApplicationController is the HTML base the
# forum uses, because Thredded's controllers inherit from ::ApplicationController.)
class ApiController < ActionController::API
  include Authentication

  rescue_from ActiveRecord::RecordNotFound do |e|
    render json: { error: e.message }, status: :not_found
  end

  rescue_from ActionController::ParameterMissing do |e|
    render json: { error: e.message }, status: :bad_request
  end
end
