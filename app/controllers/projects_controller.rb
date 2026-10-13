# JSON CRUD for projects, at /projects; the body's key is "project".
#
# A project is returned with its scripts, in order ("scripts": [{ id, name,
# language, owner, shared }]). "script_ids" in a body sets them: those
# scripts in that order, and no others. They must be the project owner's, or
# shared, or in the shared space.
class ProjectsController < ApplicationController
  include OwnerParams

  before_action :set_record, only: %i[show update destroy]

  # GET /projects  (optional ?name= ?owner= filters)
  def index
    records = in_space(Project.all).order(:id)
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

  def set_record
    @record = Project.find(params[:id])
  end

  def record_params
    body = params.require(:project)
    attrs = body.permit(:name, :description, script_ids: [])
    # An empty list is a list: it takes every script out of the project.
    attrs[:script_ids] = [] if body.key?(:script_ids) && body[:script_ids].blank?
    with_owner(attrs, body)
  end
end
