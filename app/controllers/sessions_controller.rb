# Signing in and out, at /session; the body's key is "session".
#
#   POST /session   body {"session":{"name":"peter","password":"..."}}
#     201 with {"token": "...", "user": {...}} - send the token as
#     "Authorization: Bearer <token>". 401 for a wrong name or password (the
#     answer is the same for both). Ten tries in three minutes from one address.
#   GET /session    who the token belongs to (401 if it is not valid)
#   DELETE /session signs out: the token stops working (204)
class SessionsController < ApplicationController
  # A bad token must not stop a client from signing in again.
  skip_before_action :authenticate, only: :create
  before_action :require_login!, only: %i[show destroy]

  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { render json: { error: "too many tries: wait a few minutes" }, status: :too_many_requests }

  # POST /session
  def create
    body = params.require(:session)
    user = User.authenticate(body[:name], body[:password])
    return render json: { error: "wrong name or password" }, status: :unauthorized unless user

    _record, token = ApiToken.issue(user)
    render json: { token: token, user: user_json(user) }, status: :created
  end

  # GET /session
  def show
    render json: { user: user_json(current_user) }
  end

  # DELETE /session
  def destroy
    current_token.destroy!
    head :no_content
  end

  private

  def user_json(user)
    return user.as_json if user.is_a?(LocalUser)

    user.as_json(only: %i[id name]).merge("admin" => user.admin?)
  end
end
