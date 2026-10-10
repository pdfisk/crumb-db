# Registration, at /users; the body's key is "user".
#
#   POST /users  body {"user":{"name":"peter","email":"peter@example.com"}}
#
# Creates an account (201) or answers 422 with the errors, e.g. a name that
# is taken whatever its case. The e-mail address is optional. There are no
# credentials yet: registering only reserves the name.
#
#   GET /users/:name
#
# Answers the registered user called :name (whatever its case) or 404, so a
# client can refuse to sign in as someone who has not registered.
class UsersController < ApplicationController
  # GET /users/:name
  def show
    user = User.find_by!("lower(name) = ?", params[:id].to_s.downcase)
    render json: user.as_json(only: %i[id name])
  end

  # POST /users
  def create
    user = User.new(params.require(:user).permit(:name, :email))
    if user.save
      render json: user.as_json(only: %i[id name email created_at]), status: :created
    else
      render json: { errors: user.errors }, status: :unprocessable_entity
    end
  end
end
