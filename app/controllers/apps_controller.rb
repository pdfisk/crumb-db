# JSON CRUD for apps, under three addresses:
#
#   /apps            every app; the body's key is "app"
#   /basic_sources   the Basic apps only; key "basic_source"
#   /python_sources  the Python apps only; key "python_source"
#
# The last two are the addresses the crumb client used when each language
# had a table of its own. Their routes fix the language (see routes.rb), so
# they list, find, create and change only apps in that language.
class AppsController < ApplicationController
  include OwnerParams

  before_action :set_record, only: %i[show update destroy]

  # GET /apps  (optional ?name= ?owner= ?language= ?owner_id= ?visibility= filters)
  def index
    records = in_space(apps).order(:id)
    records = records.where(name: params[:name]) if params[:name].present?
    unless fixed_language
      %i[language owner_id visibility].each do |field|
        records = records.where(field => params[field]) if params[field].present?
      end
    end
    render json: records
  end

  # GET /apps/:id
  def show
    render json: @record
  end

  # POST /apps
  def create
    record = apps.new(record_params)
    if record.save
      render json: record, status: :created, location: record
    else
      render json: { errors: record.errors }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /apps/:id
  def update
    if @record.update(record_params)
      render json: @record
    else
      render json: { errors: @record.errors }, status: :unprocessable_entity
    end
  end

  # DELETE /apps/:id
  def destroy
    @record.destroy!
    head :no_content
  end

  private

  # The language a /basic_sources or /python_sources route fixes; nil on /apps.
  def fixed_language
    request.path_parameters[:language]
  end

  def apps
    fixed_language ? App.where(language: fixed_language) : App.all
  end

  def set_record
    @record = apps.find(params[:id])
  end

  def record_params
    if fixed_language
      body = params.require(:"#{fixed_language}_source")
      attrs = body.permit(:name, :content, :priority, :compiled, :compiled_code)
    else
      body = params.require(:app)
      attrs = body.permit(:name, :content, :priority, :compiled, :compiled_code,
                          :language, :owner_id, :visibility, :version)
    end
    with_owner(attrs, body)
  end
end
