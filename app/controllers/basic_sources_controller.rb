class BasicSourcesController < ApplicationController
  before_action :set_record, only: %i[show update destroy]

  # GET /basic_sources  (optional ?name= filter)
  def index
    records = BasicSource.order(:id)
    records = records.where(name: params[:name]) if params[:name].present?
    render json: records
  end

  # GET /basic_sources/:id
  def show
    render json: @record
  end

  # POST /basic_sources
  def create
    record = BasicSource.new(record_params)
    if record.save
      render json: record, status: :created, location: record
    else
      render json: { errors: record.errors }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /basic_sources/:id
  def update
    if @record.update(record_params)
      render json: @record
    else
      render json: { errors: @record.errors }, status: :unprocessable_entity
    end
  end

  # DELETE /basic_sources/:id
  def destroy
    @record.destroy!
    head :no_content
  end

  private

  def set_record
    @record = BasicSource.find(params[:id])
  end

  def record_params
    params.require(:basic_source).permit(:name, :content, :priority, :compiled, :compiled_code)
  end
end
