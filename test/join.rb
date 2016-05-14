require_relative './db'

# puts User.joins(:phone_device)

# joins: default inner join
# phones = User.joins(:phone_device)
# puts phones.length

phones = PhoneDevice.eager_load(:user)
phones.each { |phone|
	puts phone.id
	if phone.user.nil?
		puts 'user nil'
	else
		puts phone.user.app_id
	end
}
