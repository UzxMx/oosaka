module Osk
	class DataBuffer
		EOL = ["\r", "\n"]

		attr_accessor :start_offset

		def initialize(data)
			@data = data

			@start_offset = 0
		end

		def length
			@data.length
		end

		def [](i)
			@data[i]
		end

		def data
			@data
		end

		# next \r\n
		def next_crlf
			result = false
			i = @start_offset
			while i < (@data.length - 1)
				if @data[i] == EOL[0] and @data[i + 1] == EOL[1]
					result = @data.slice(@start_offset, i - @start_offset)
					@start_offset = i + 2
					break;
				end
				i += 1
			end
			result
		end

		def remaining_data?
			@start_offset < @data.length
		end

		def remaining_data
			@data.slice(@start_offset, @data.length - @start_offset)
		end

		def remaining_length
			@data.length - @start_offset
		end

		def drain_all
			@start_offset = @data.length
		end
	end
end