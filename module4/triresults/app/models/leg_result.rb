class LegResult
	include Mongoid::Document

	field :secs, type: Float

	embedded_in :entrant
	embeds_one :event, as: :parent

	validates :event, presence: true

	def calc_ave
		#subclasses BikeResult, RunResult, and SwimResult will calculate 
		#individual, event-specific averages
	end

	after_initialize do |doc|
		doc.calc_ave
	end

	def secs= value
		self[:secs] = value
		calc_ave
	end
end
