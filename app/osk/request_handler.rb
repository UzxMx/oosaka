require_relative './server'
require_relative './message'
require_relative './models/phone_device'
require 'fileutils'

module Osk

	class Interceptor
		def intercept(data)
		end
	end

	class LogInterceptor
		include Osk

		def initialize(connection, message)
			@connection = connection
			@connection.interceptor = self

			@id = message['id']
			@command = message['command']
			content = message['content']
			@boundary = content['boundary']
			@boundary_size = @boundary.length
			d = DateTime.now
			path = File.join(Osk.logs_dir, "#{@connection.user.id}")
			unless File.directory?(path)
				FileUtils.mkdir_p(path)
			end
			path = File.join(path, d.strftime('%Y-%m-%d') + ".log")
			@file = File.open(path, 'a+')
			@stage = :first_boundary_not_found
			@buf = ""
			@rx = /#{Regexp.quote(@boundary)}(\r\n|--)/

			@total_write_count = 0
		end

		def intercept(data)
			data_length = data.remaining_length
			@buf << data.remaining_data
			if @stage == :first_boundary_not_found
				if @buf.gsub!(/\A#{Regexp.quote(@boundary)}\r\n/, '')
					@stage = :first_boundary_found
					logger.debug('found first boundary')
				else
					data.drain_all
					logger.debug('not found first boundary')
					return
				end
			end

			loop do
				logger.debug("buf:#{@buf}")
				if i = @buf.index(@rx)
					logger.debug("found next boundary at #{i}")
					@file.write(@buf.slice!(0, i))
					@total_write_count += i
					@buf.slice!(0, @boundary_size + 2)
					if $1 == "--"
						break
					end
					next
				else
					@total_write_count += @buf.length
					@file.write(@buf.slice!(0, @buf.length))
					data.drain_all
					logger.debug('write all to file')
					return
				end
			end

			logger.info("save file success. total write count: #{@total_write_count}")

			cost_length = data_length - @buf.length
			if cost_length > 0
				data.start_offset = data.start_offset + cost_length
			end

			@connection.interceptor = nil
			@file.close

			@connection.send_resp(@command + '_return', @id, nil)
		end
	end

	class RequestHandler
		include Osk

		def initialize(connection)
			@connection = connection
		end

		def handle_request(message, data)
			id = message['id']
			type = message['type']
			command = message['command']

			if !id or id <= 0
				logger.error 'Message id format is invalid'
			end

			case type
			when Message::Type::INFO
				case command
				when Message::Command::SEND_IDENTITY
					cmd_send_identity(message)
				else
					logger.error 'Message unknown command'
				end
			when Message::Type::QUERY
				case command
				when Message::Command::UPLOAD_ALL_LOGS
					resp_fetch_all_logs(message, data)
				else
					logger.error 'Message unknown command'
				end
			when Message::Type::RESP
				case command
				when Message::Command::GET_DEVICE_INFO
					resp_get_device_info(message)
				when Message::Command::FETCH_ALL_LOGS
					resp_fetch_all_logs(message, data)
				else
					logger.error 'Message unknown command'
				end
			else
				logger.error 'Message type is invalid'
			end
		end

		def cmd_send_identity(message)
			content = message['content']
			app_id = content['app_id']
			device_id = content['device_id']
			phone_device = nil

			if !User.exists?(app_id: app_id, device_id: device_id)
				user = User.new(app_id: app_id, device_id: device_id, online: true)
				user.save
			else
				user = User.where(app_id: app_id, device_id: device_id).first
				user.online = true
				user.save
				phone_device = PhoneDevice.where(user_id: user.id).first
			end

			if phone_device
				@connection.device = phone_device
			else
				@connection.captain.fetch_device_info
			end

			@connection.user = user
			@connection.on_connection_bound
		end

		def resp_get_device_info(message)
			content = message['content']
			device_info = content['device_info']
			user_info = content['user_info']
			user = @connection.user
			phone_device = PhoneDevice.where(user_id: user.id).first
			if phone_device.nil?
				phone_device = PhoneDevice.new
				phone_device.user_id = user.id
			end
			phone_device.attributes = device_info
			phone_device.fetched_at = DateTime.now
			phone_device.save

			unless user_info.nil?
				updated = false
				unless user_info['username'].nil?
					user.username = user_info['username']
					updated = true
				end

				if updated
					user.save
				end
			end
		end

		def resp_fetch_all_logs(message, data)
			logger.debug('create log interceptor')
			interceptor = LogInterceptor.new(@connection, message)
			interceptor.intercept(data)
		end
	end
end