require_relative '../../lib/export_client/client.rb'

class ExportController < ApplicationController

  include ExportClient

  before_action :initialize, only: [:create, :update]
  before_action :set_export, only: [:show, :update, :file]
  before_action :validate_request, only: :create
  before_action :validate_action, only: :update

  def new
    @export = Export.new
  end

  def create
    @export = Export.new export_params
    if @export.save
      render json: @export, status: :created, location: @export
      @client.fetch
    else
      render json: { description: 'Create failed' ,errors: @export.errors.messages }, status: :unprocessable_entity
    end
  end

  def show
    render json: @export
  end

  def update
    case params[:action]
      when pause
        @client.pause_export
      when stop
        @client.stop_export
      when resume
        @client.fetch
      else
        render json: { description: 'Enter valid action.', errors: 'Invalid action' }, status: :method_not_allowed
    end
  end

  def file
    @file = File.new("#{params['domain']}_tickets.json")
    render json: { success: true, file: { name: "#{params['domain']}_tickets.json" } }
  end

  private

  def set_export
    @export = Export.find_by_id(params[:id])
    render json: { description: 'Export not found', errors: 'Export not found' }, status: :not_found unless @export
  end

  def initialize
    @client = Client.new params.join({start_time: @export[:last_fetch_time] || 0})
  end

  def validate_request
    params.permit(:domain, :api_token,:email)
  end

  def validate_action
    params.permit(:action)
  end

  def export_params
    params.require(:export).permit(:domain,:api_token, :email)
  end
end
