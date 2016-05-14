module Osk

	class << self

		attr_accessor :logger, :logs_dir
	end

	def logger
		Osk.logger
	end
end

