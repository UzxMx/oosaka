require 'active_record'

class User < ActiveRecord::Base
	has_one :phone_device
end