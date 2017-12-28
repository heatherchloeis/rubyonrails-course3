module Api
	class RacesController < ApplicationController
		before_action :set_race, only: [:update, :destroy]
		before_action :set_format, only: [:update]

		rescue_from ActionView::MissingTemplate do |exception|
			Rails.logger.debug("Accept:#{request.accept}")
			render plain: "woops: we do not support that content-type[#{request.accept}]", status: :unsupported_media_type
		end

		rescue_from Mongoid::Errors::DocumentNotFound do |exception|
			@msg = "woops: cannot find race[#{params[:id]}]"
			if !request.accept || request.accept == "*/*"
				render plain: @msg, status: :not_found
			else
				if request.format.json?
					render json: {"msg" => @msg}, 
					status: :not_found,
					template: "api/error_msg"
				elsif request.format.xml?
					render xml: {"msg" => @msg},
					status: :not_found,
					template: "api/error_msg"
				end				
			Rails.logger.debug("Accept:#{request.accept}")
			end
		end

		def index
			if !request.accept || request.accept == "*/*"
				render plain: "/api/races, offset=[#{params[:offset]}], limit=[#{params[:limit]}]"
			else
				#real implementation
			end
		end

		def create
			if !request.accept || request.accept == "*/*"
				render plain: params[:race][:name], status: :ok
			else
				@race = Race.create (race_params)
				render plain: @race.name, status: :created
			end
		end

		def show
			if !request.accept || request.accept == "*/*"
				render plain: "/api/races/#{params[:id]}"
			else
				set_race
				if @race
					render action: :race
				end
			end
		end

		def update
			if !request.accept || request.accept == "*/*"
				render plain: :nothing, status: :ok
			else
				Rails.logger.debug("method=#{request.method}")
				@race.update(race_params)
				if request.headers["Content-Type"].include? "application/json"
					render json: @race
				else
					render xml: @race
				end
			end
		end

		def destroy
			set_race
			if @race.destroy
				render nothing: true, status: :no_content
			end
		end

		private
			def race_params
				params.require(:race).permit(:name, :date, :city, :state, :swim_distance, :swim_units, :bike_distance, :bike_units, :run_distance, :run_units) if params["race"]
			end

			def set_race
				@race = Race.find(params[:id])
			end

			def set_format
			end
	end
end