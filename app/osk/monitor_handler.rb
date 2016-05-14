require_relative './server'
require_relative './models/user'
require_relative './models/phone_device'

module Osk

	class MonitorHandler
		include Osk

		def initialize(connection)
			@connection = connection
		end

		def handle_request(message)
			case message['command']
			when 'get_devices'
				cmd_get_devices(message)
			when 'fetch_all_logs'
				cmd_fetch_all_logs(message)
			when 'get_user_logs_dir'
				cmd_get_user_logs_dir(message)
			when 'get_device_info'
				cmd_get_device_info(message)
			when 'fetch_device_info'
				cmd_fetch_device_info(message)
			when 'configure_logger'
				cmd_configure_logger(message)
			else
				logger.error 'Unknown command'
			end
		end

		# params:
		#
		# app_id
		# online?
		# start
		# max_count
		#
		# return:
		# total devices, online devices, records
		def cmd_get_devices(message)
			content = message['content']
			app_id = content['app_id']
			app_id = 'kumamoto' if app_id.nil?
			start = content['start']
			puts "start: #{start}"
			start = 0 if start.nil?
			max_count = content['max_count']
			max_count = 15 if max_count.nil?

			where_conds = {'app_id' => app_id}
			if !content['online'].nil?
				where_conds['online'] = content['online']
			end
			users = User.where(where_conds).offset(start).limit(max_count).eager_load(:phone_device)
			records = []
			users.each do |user|
				record = { user: user.as_json(except: [:app_id, :updated_at]) }
				phone_device = user.phone_device
				if phone_device
					record[:device] = phone_device.as_json(except: [:user_id, :created_at, :updated_at])
				end
				records << record
			end

			total_count = User.where(app_id: app_id).count
			online_count = User.where(app_id: app_id, online: true).count

			resp = {
				total_count: total_count,
				online_count: online_count,
				records: records
			}

			@connection.send_message(resp)
		end

		def cmd_fetch_all_logs(message)
			get_app_connection(message).captain.fetch_all_logs
		end

		def cmd_get_user_logs_dir(message)
			content = message['content']
			id = content['id']
			@connection.send_message({
				path: File.join(Osk.logs_dir, "#{id}")
			})
		end

		def cmd_get_device_info(message)
			content = message['content']
			id = content['id']

			user = User.where(id: id).eager_load(:phone_device).first

			resp = {}
			resp[:user_info] = user.as_json(except: [:app_id, :updated_at])
			unless user.phone_device.nil?
				resp[:device_info] = user.phone_device.as_json(except: [:user_id, :created_at])
				unless user.phone_device.fetched_at.nil?
					resp[:device_info][:fetched_at] = user.phone_device.fetched_at.in_time_zone('Beijing').strftime('%Y-%m-%d %H:%M:%S')		 	
				end 
			end

			@connection.send_message(resp)
		end

		def cmd_fetch_device_info(message)
			get_app_connection(message).captain.fetch_device_info
		end

		def cmd_configure_logger(message)
			captain = get_app_connection(message).captain
			content = message['content']
			content.delete('id')
			captain.configure_logger(content)
		end

		private
			def get_app_connection(message)
				content = message['content']
				id = content['id']
				AppConnectionManager.get_connection(id)
			end
	end
end