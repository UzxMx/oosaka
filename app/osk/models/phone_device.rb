require 'active_record'

class PhoneDevice < ActiveRecord::Base
	belongs_to :user
end