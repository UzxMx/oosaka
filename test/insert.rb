require_relative './db'
require 'securerandom'

for i in 1..150
	user = User.new(
		app_id: 'kumamoto',
		device_id: SecureRandom.uuid,
		username: "Rick#{i}",
		online: true)
	user.save
	device = PhoneDevice.new
	device.user = user
	device.save
end

for i in 1..150
	user = User.new(
		app_id: 'kumamoto',
		device_id: SecureRandom.uuid,
		username: "Hans#{i}",
		online: false)
	user.save
	device = PhoneDevice.new
	device.user = user
	device.save
end