# Registration, at /users; the body's key is "user".
#
#   POST /users  body {"user":{"name":"peter","password":"...","email":"peter@example.com"}}
#
# Creates an account (201, with a sign-in token as POST /session gives) or
# answers 422 with the errors, e.g. a name that is taken whatever its case or a
# password shorter than 8 characters. The e-mail address is optional. Ten
# tries in three minutes from one address.
#
#   GET /users/:name
#
# Answers the registered user called :name (whatever its case) or 404, so a
# client can tell whether a name is taken.
class UsersController < ApplicationController
  # A stale token must not stop someone from registering.
  skip_before_action :authenticate, only: :create

  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { render json: { error: "too many tries: wait a few minutes" }, status: :too_many_requests }

  # GET /users/:name
  def show
    user = User.find_by!("lower(name) = ?", params[:id].to_s.downcase)
    render json: user.as_json(only: %i[id name])
  end

  # POST /users
  def create
    user = User.new(params.require(:user).permit(:name, :email, :password))
    if user.save
      _record, token = ApiToken.issue(user)
      render json: user.as_json(only: %i[id name email created_at]).merge("token" => token), status: :created
    else
      render json: { errors: user.errors }, status: :unprocessable_entity
    end
  end
end
