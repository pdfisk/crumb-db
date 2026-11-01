# JSON CRUD for projects, at /projects; the body's key is "project".
#
# A project is returned with "scripts": the project's own copies of its
# scripts, in order, each { name, language, content, priority?, compiled_code? }
# (see Project). "scripts" in a body sets the list: those, in that order, and
# no others. Names must be unique within the project, ignoring case. "shared"
# (true or false, default false) says whether the owner has shared the project.
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

  # DELETE /projects/:id  (its scripts go with it; the scripts table is untouched)
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
    attrs = body.permit(:name, :description, :shared, scripts: %i[name language content priority compiled_code])
    # An empty list is a list: it takes every script out of the project.
    attrs[:scripts] = [] if body.key?(:scripts) && body[:scripts].blank?
    with_owner(attrs, body)
  end
end
