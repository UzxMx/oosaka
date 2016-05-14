# below one will not work
# require '../osk'
require_relative '../osk'
require_relative './request_handler'
require_relative './monitor_handler'
require_relative './models/user'
require_relative './data_buffer'
require 'eventmachine'
require 'json'
require 'thread'

EOL = ["\r", "\n"]

module Osk

	class CommandId
		def initialize
			@id = 1
			@lock = Mutex.new
		end

		def get_new_id
			id = nil
			@lock.synchronize {
				id = @id
				@id += 1
			}
			id
		end
	end

	class AppConnectionManager
		@connections = {}

		class << self
			def get_connection(user_id)
				@connections[user_id.to_s]
			end

			def add_connection(user_id, connection)
				@connections[user_id.to_s] = connection
			end

			def remove_connection(user_id)
				@connections.delete(user_id)
			end

			def connection_count
				@connections.length
			end
		end
	end

	class AppConnectionCaptain
		def initialize(connection)
			@connection = connection
		end

		def fetch_all_logs
			@connection.send_request(Message::Type::QUERY, Message::Command::FETCH_ALL_LOGS, nil)
		end

		def fetch_device_info
			@connection.send_request(Message::Type::QUERY, Message::Command::GET_DEVICE_INFO, nil)
		end

		def configure_logger(content)
			@connection.send_request(Message::Type::INFO, Message::Command::CONFIGURE_LOGGER, content)			
		end
	end

	class AppConnection < EM::Connection
		include Osk

		attr_accessor :user, :device, :interceptor

		def initialize
			@str_buffer = StringIO.new
			@cr_found = false

			@captain = AppConnectionCaptain.new(self)
			@cmd_id = CommandId.new
			@request_handler = RequestHandler.new(self)
		end

		def captain
			@captain
		end

		def post_init
			logger.debug "-- someone connected to the echo server!"
		end

		def on_connection_bound
			AppConnectionManager.add_connection(user.id, self)
		end

		# data.length equals the byte count of data, so the element of data
		# is just one byte
		def receive_data(data)
			logger.debug "receive_data: size: #{data.length} #{data}"

			if data.length <= 0
				return
			end

			data = DataBuffer.new(data)

			if interceptor
				interceptor.intercept(data)
			end

			if @cr_found
				@cr_found = false
				if data[0] == EOL[1]
					message_found(data)
					data.start_offset = 1
				else
					@str_buffer.truncate(@str_buffer.length - 1)
				end
			end

			while str = data.next_crlf
				@str_buffer << str
				message_found(data)
			end

			if data.remaining_data?
				@cr_found = data[data.length - 1] == EOL[0]
				@str_buffer << data.remaining_data
			end
		end

		def message_found(data)
			logger.debug("size: #{@str_buffer.string.length}: #{@str_buffer.string}")

			message = JSON.parse(@str_buffer.string)
			@str_buffer = StringIO.new
			@request_handler.handle_request(message, data)
		end

		def send_message(type, command, id, content)
			message = {id: id, type: type, command: command}
			message["content"] = content if content

			logger.debug("send: #{message}")

			buf = StringIO.new
			buf << JSON.generate(message)
			buf << "\r\n"

			send_data(buf.string)
		end

		def send_request(type, command, content)
			id = @cmd_id.get_new_id
			send_message(type, command, id, content)
		end

		def send_resp(command, id, content)
			send_message(Message::Type::RESP, command, id, content)
		end

		def unbind
			if user
				user.online = false
				user.save

				AppConnectionManager.remove_connection(user.id)
			end

			logger.debug "-- someone disconnected from the echo server!"
		end
	end

	class MonitorConnection < EM::Connection
		include Osk

		def initialize
			@str_buffer = StringIO.new
			@cr_found = false

			@monitor_handler = MonitorHandler.new(self)
		end
		
		def post_init
			logger.debug 'monitor connection created'
		end

		def receive_data(data)
			logger.debug "receive_data: #{data}"

			if data.length <= 0
				return
			end

			start = i = 0

			if @cr_found
				@cr_found = false
				if data[0] == EOL[1]
					message_found
					start = i = 1
				end
			end

			while i < (data.length - 1)
				if data[i] == EOL[0]
					if data[i + 1] == EOL[1]
						@str_buffer << data.slice(start, i - start)
						
						message_found

						i += 2
						start = i
						next
					end
				end
				i += 1
			end

			if i == data.length - 1
				@cr_found = data[i] == EOL[0]
				@str_buffer <<	data.slice(start, i - start + 1)
			end
		end

		def message_found
			message = JSON.parse(@str_buffer.string)
			@str_buffer = StringIO.new
			@monitor_handler.handle_request(message)
		end

		def send_message(content)
			message = {content: content}

			buf = StringIO.new
			buf << JSON.generate(message)
			buf << "\r\n"

			send_data(buf.string)
		end

		def unbind
			logger.debug 'monitor connection removed'
		end
	end
end