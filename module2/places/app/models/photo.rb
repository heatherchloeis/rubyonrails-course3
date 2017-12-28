class Photo
	require 'exifr/jpeg'

	include Mongoid::Document
	include ActiveModel::Model

	Mongo::Logger.logger.level = ::Logger::INFO

	belongs_to :place

	attr_accessor :id, :location, :contents

	def self.mongo_client
		Mongoid::Clients.default
	end

	def initialize(params = nil)
		@id = params[:_id].to_s unless params.nil?
		@location = Point.new(params[:metadata][:location]) unless params.nil?
	end

	def persisted?
		!@id.nil?
	end

	def save
		if !persisted?
			gps = EXIFR::JPEG.new(@contents).gps
			location = Point.new(lng: gps.longitude, lat: gps.latitude)
			@contents.rewind
			description = {}
			description[:metadata] = {location: location.to_hash, place: @place}
			description[:content_type] = "image/jpeg"
			@location = Point.new(location.to_hash)
			grid_file = Mongo::Grid::File.new(@contents.read, description)
			@id = Place.mongo_client.database.fs.insert_one(grid_file).to_s
		else
			doc = Photo.mongo_client.database.fs.find({_id: BSON::ObjectId.from_string(@id)}).first
			doc[:metadata][:place] = @place
			doc[:metadata][:location] = @location.to_hash
			Photo.mongo_client.database.fs.find({_id: BSON::ObjectId.from_string(@id)}).update_one(doc)
		end
	end

	def self.all(offset = 0, limit = 0)
		mongo_client.database.fs.find.skip(offset).limit(limit).map { |result|
			Photo.new(result)
		}
	end

	def self.find(id)
		result = mongo_client.database.fs.find(:_id => BSON::ObjectId.from_string(id)).first
		if !result.nil?
			Photo.new(result)
		end
	end

	def contents
		result = mongo_client.database.fs.find_one(:_id => BSON::ObjectId.from_string(id))

		if result
			buffer = ""
			result.chunks.reduce([]) do |x, chunk|
				buffer << chunk.data.data
			end
			return buffer
		end
	end

	def destroy
		mongo_client.database.fs.find(:_id => BSON::ObjectId.from_string(@id)).delete_one
	end

	def find_nearest_place_id(max_meters)
		options = {'geometry.geolocation' => {:$near => @location.to_hash}}
		Place.collection.find(options).limit(1).projection({_id: 1}).first[:_id]
	end

	def place
		Place.find(@place.to_s) unless place.nil?
	end

	def place=(object)
		@place = object
		@place = BSON::ObjectId.from_string(object) if object.is_a? String
		@place = BSON::ObjectId.from_string(object_id) if object.respond_to? :id
	end

	def self.find_photos_for_place(id)
		mongo_client.database.fs.find({'metadata.place' => BSON::ObjectId.from_string(id)})
	end
end