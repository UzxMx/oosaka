module Osk
	module Message
		module Type
			INFO = 'info'
			QUERY = 'query'
			RESP = 'resp'
		end

		module Command
			SEND_IDENTITY = 'send_identity'
			GET_DEVICE_INFO = 'get_device_info'
			FETCH_ALL_LOGS = 'fetch_all_logs'
			FETCH_ALL_LOGS_RETURN = 'fetch_all_logs_return'
			UPLOAD_ALL_LOGS = 'upload_all_logs'
			UPLOAD_ALL_LOGS_RETURN = 'upload_all_logs_return'
			CONFIGURE_LOGGER = 'configure_logger'
		end
	end
end