# JSON CRUD for scripts, under three addresses:
#
#   /scripts         every script; the body's key is "script"
#   /basic_sources   the Basic scripts only; key "basic_source"
#   /python_sources  the Python scripts only; key "python_source"
#
# The last two are the addresses the crumb client used when each language
# had a table of its own. Their routes fix the language (see routes.rb), so
# they list, find, create and change only scripts in that language.
class ScriptsController < ApplicationController
  include OwnerParams

  before_action :set_record, only: %i[show update destroy]

  # GET /scripts  (optional ?name= ?owner= ?language= ?owner_id= ?visibility= filters)
  def index
    records = in_space(scripts).order(:id)
    records = records.where(name: params[:name]) if params[:name].present?
    unless fixed_language
      %i[language owner_id visibility].each do |field|
        records = records.where(field => params[field]) if params[field].present?
      end
    end
    render json: records
  end

  # GET /scripts/:id
  def show
    render json: @record
  end

  # POST /scripts
  def create
    record = scripts.new(record_params)
    if record.save
      render json: record, status: :created, location: record
    else
      render json: { errors: record.errors }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /scripts/:id
  def update
    if @record.update(record_params)
      render json: @record
    else
      render json: { errors: @record.errors }, status: :unprocessable_entity
    end
  end

  # DELETE /scripts/:id
  def destroy
    @record.destroy!
    head :no_content
  end

  private

  # The language a /basic_sources or /python_sources route fixes; nil on /scripts.
  def fixed_language
    request.path_parameters[:language]
  end

  def scripts
    fixed_language ? Script.where(language: fixed_language) : Script.all
  end

  def set_record
    @record = scripts.find(params[:id])
  end

  def record_params
    if fixed_language
      body = params.require(:"#{fixed_language}_source")
      attrs = body.permit(:name, :content, :priority, :compiled, :compiled_code,
                          :shared, :project_name)
    else
      body = params.require(:script)
      attrs = body.permit(:name, :content, :priority, :compiled, :compiled_code,
                          :language, :owner_id, :visibility, :version,
                          :shared, :project_name)
    end
    with_owner(attrs, body)
  end
end
