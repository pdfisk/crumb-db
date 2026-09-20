class PythonSourcesController < ApplicationController
  before_action :set_record, only: %i[show update destroy]

  # GET /python_sources  (optional ?name= filter)
  def index
    records = PythonSource.order(:id)
    records = records.where(name: params[:name]) if params[:name].present?
    render json: records
  end

  # GET /python_sources/:id
  def show
    render json: @record
  end

  # POST /python_sources
  def create
    record = PythonSource.new(record_params)
    if record.save
      render json: record, status: :created, location: record
    else
      render json: { errors: record.errors }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /python_sources/:id
  def update
    if @record.update(record_params)
      render json: @record
    else
      render json: { errors: @record.errors }, status: :unprocessable_entity
    end
  end

  # DELETE /python_sources/:id
  def destroy
    @record.destroy!
    head :no_content
  end

  private

  def set_record
    @record = PythonSource.find(params[:id])
  end

  def record_params
    params.require(:python_source).permit(:name, :content)
  end
end
