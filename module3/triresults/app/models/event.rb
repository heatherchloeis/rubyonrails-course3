class Event
	include Mongoid::Document

	field :o, as: :order, type: Integer
	field :n, as: :name, type: String
	field :d, as: :distance, type: Float
	field :u, as: :units, type: String

	embedded_in :parent, polymorphic: true, touch: true

	validates :order, :name, :presence => true

	def meters
		case units
		when 'kilometers' then return distance*1000
		when 'yards' then return distance*0.9144
		when 'miles' then return distance*1609.344
		when 'meters' then distance
		end
	end

	def miles
		case units
		when 'yards' then return distance*0.000568182
		when 'meters' then return distance*0.000621371
		when 'kilometers' then return distance*0.621371
		when 'miles' then distance
		end
	end
end
