class Place
	include ActiveModel::Model
	attr_accessor :id, :formatted_address, :location, :address_components

	def self.mongo_client
		Mongoid::Clients.default
	end

	def self.collection
		self.mongo_client['places']
	end

	def persisted?
		!@id.nil?
	end

	def self.load_all(f)
		parsedFile = JSON.parse(f.read)
		collection.insert_many(parsedFile)
	end

	def initialize(params)
		@id = params[:_id].to_s

		@address_components = []
		if !params[:address_components].nil?
			address_components = params[:address_components]
			address_components.each { |a| @address_components << AddressComponent.new(a) }
		end

		@formatted_address = params[:formatted_address]
		@location = Point.new(params[:geometry][:geolocation])
	end

	def self.find_by_short_name(s)
		Place.collection.find({"address_components.short_name": s})
	end

	def self.to_places(input)
		results = []

		input.each { |i|
			results << Place.new(i)
		}
		return results
	end

	def self.find(id)
		result = collection.find(:_id => BSON::ObjectId.from_string(id)).first
		if !result.nil?
			Place.new(result)
		end
	end

	def self.all(offset = 0, limit = nil)
		results = collection.find.skip(offset)
		unless limit.nil?
			results = results.limit(limit)
		end

		results.map { |result|
			Place.new(result)
		}
	end

	def destroy
		self.class.collection.find({:_id => BSON::ObjectId(@id)}).delete_one
	end

	def self.get_address_components(sort = nil, offset = nil, limit = nil)
		pipeline = [
			{:$unwind => '$address_components'},
			{:$project => {formatted_address: 1, address_components: 1, geometry: {geolocation: 1}}}
		]

		pipeline << {:$sort => sort} unless sort.nil?
		pipeline << {:$skip => offset} unless offset.nil?
		pipeline << {:$limit => limit} unless limit.nil?

		collection.find.aggregate(pipeline)			
	end

	def self.get_country_names
		collection.find.aggregate([
			{:$project => {_id: 0, address_components: {long_name: 1, types: 1}}},
			{:$unwind => '$address_components'},
			{:$unwind => '$address_components.types'},
			{:$match => {'address_components.types' => 'country'}},
			{:$group => {:_id => '$address_components.long_name'}}
		]).to_a.map { |h| h[:_id] }
	end

	def self.find_ids_by_country_code(country_code)
		collection.find.aggregate([
			{:$unwind => '$address_components'},
			{:$match => {'$address_components.short_name' => country_code}},
			{:$project => {_id: 1}}
		]).to_a.map { |doc| doc[:_id].to_s }
	end

	def self.create_indexes 
		collection.indexes.create_one("geometry.geolocation" => Mongo::Index::GEO2DSPHERE)
	end

	def self.remove_indexes
		collection.indexes.drop_one("geometry.geolocation_2dsphere")
	end

	def self.near(point, max_meters = nil)
		collection.find(
			{'geometry.geolocation' => {:$near => {:$geometry => point.to_hash, :$maxDistance => max_meters}}}
		)
	end

	def near(max_meters = nil)
		max_meters = max_meters.nil? ? 1000 : max_meters.to_i
		Place.to_places(Place.near(@location, max_meters))
	end

	def photos(offset = 0, limit = nil)
		photos = Photo.find_photos_for_place(@id).skip(offset)
		photos = photos.limit(limit) unless limit.nil?
		photos = photos.map { |photo| 
			Photo.new(photo)
		}
	end
end