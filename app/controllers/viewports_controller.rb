class ViewportsController < ApplicationController
  include OwnerParams

  before_action :set_record, only: %i[show update destroy]

  # GET /viewports  (optional ?name= ?owner= filters)
  def index
    records = in_space(Viewport.all).order(:id)
    records = records.where(name: params[:name]) if params[:name].present?
    render json: records
  end

  # GET /viewports/:id
  def show
    render json: @record
  end

  # POST /viewports
  def create
    record = Viewport.new(record_params)
    if record.save
      render json: record, status: :created, location: record
    else
      render json: { errors: record.errors }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /viewports/:id
  def update
    if @record.update(record_params)
      render json: @record
    else
      render json: { errors: @record.errors }, status: :unprocessable_entity
    end
  end

  # DELETE /viewports/:id
  def destroy
    @record.destroy!
    head :no_content
  end

  private

  def set_record
    @record = Viewport.find(params[:id])
  end

  # content is a free-form JSON object (widgets nested in widgets), which
  # permit cannot describe key by key, so it is taken as it came.
  def record_params
    attrs = params.require(:viewport).permit(:name).to_h
    if params[:viewport].key?(:content)
      raw = params[:viewport][:content]
      attrs[:content] = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw
    end
    with_owner(attrs, params[:viewport])
  end
end
