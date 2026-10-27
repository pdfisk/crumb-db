# JSON CRUD for projects, at /projects; the body's key is "project".
#
# A project is returned with "scripts": a list of "<owner>/<name>" strings, in
# order ("/name" is a script in the shared space), kept in the project's own
# record; there are no foreign keys, so a name may be of a script that has
# gone. "scripts" in a body sets the list: those, in that order, and no others.
# They must be the project owner's, or in the shared space. "shared" (true or
# false, default false) says whether the owner has shared the project.
class ProjectsController < ApplicationController
  include OwnerParams

  before_action :require_login!, only: %i[create update destroy]
  before_action :set_record, only: %i[show update destroy]
  before_action :authorize_modify!, only: %i[update destroy]

  # GET /projects  (optional ?name= ?owner= filters). Shared projects, ones in
  # the shared space and the caller's own.
  def index
    records = in_space(Project.visible_to(current_user)).order(:id)
    records = records.where(name: params[:name]) if params[:name].present?
    render json: records
  end

  # GET /projects/:id
  def show
    render json: @record
  end

  # POST /projects
  def create
    record = Project.new(record_params)
    if record.save
      render json: record, status: :created, location: record
    else
      render json: { errors: record.errors }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /projects/:id
  def update
    if @record.update(record_params)
      render json: @record
    else
      render json: { errors: @record.errors }, status: :unprocessable_entity
    end
  end

  # DELETE /projects/:id  (its scripts stay, and stay in other projects)
  def destroy
    @record.destroy!
    head :no_content
  end

  private

  # A project the caller may not see is not found, whatever is asked of it.
  def set_record
    @record = Project.find(params[:id])
    raise ActiveRecord::RecordNotFound, "Couldn't find Project with 'id'=#{params[:id]}" unless @record.visible_to?(current_user)
  end

  def record_params
    body = params.require(:project)
    attrs = body.permit(:name, :description, :shared, scripts: [])
    # An empty list is a list: it takes every script out of the project.
    attrs[:scripts] = [] if body.key?(:scripts) && body[:scripts].blank?
    with_owner(attrs, body)
  end
end
