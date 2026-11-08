# Signing in to and out of the forum, with the same names and passwords as the
# IDE (User.authenticate).
#
#   GET    /sign_in   the form (return_to: where to go afterwards)
#   POST   /sign_in   signs in; ten tries in three minutes from one address
#   DELETE /sign_out  signs out
#   GET    /sso       signs in with a one-time code from the IDE (ForumHandoff)
class ForumSessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { too_many_tries }
  rate_limit to: 30, within: 1.minute, only: :sso,
             with: -> { redirect_to main_app.forum_sign_in_path, alert: "Too many tries: wait a minute." }

  # GET /sign_in
  def new
    @return_to = safe_return_to(params[:return_to])
  end

  # POST /sign_in
  def create
    @return_to = safe_return_to(params[:return_to])
    user = User.authenticate(params[:name], params[:password])
    if user
      forum_sign_in(user)
      redirect_to @return_to, notice: "Signed in as #{user.name}."
    else
      @name = params[:name]
      flash.now[:alert] = "Wrong name or password."
      render :new, status: :unprocessable_entity
    end
  end

  # GET /sso?code=...&return_to=...
  # The code is spent whatever happens next, and the redirect takes it out of
  # the address bar.
  def sso
    user = ForumHandoff.redeem(params[:code])
    if user
      forum_sign_in(user)
      redirect_to safe_return_to(params[:return_to])
    else
      redirect_to main_app.forum_sign_in_path(return_to: ForumHandoff.local_path(params[:return_to])),
                  alert: "That sign-in link has expired or was already used. Sign in here, or use the Forum button in the IDE again."
    end
  end

  # DELETE /sign_out
  def destroy
    forum_sign_out
    redirect_to forum_root_path, notice: "Signed out."
  end

  private

  def too_many_tries
    @return_to = safe_return_to(params[:return_to])
    flash.now[:alert] = "Too many tries: wait a few minutes."
    render :new, status: :too_many_requests
  end
end
