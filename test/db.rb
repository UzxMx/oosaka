require_relative '../app/osk/models/user'
require_relative '../app/osk/models/phone_device'

ActiveRecord::Base.logger = Logger.new(STDOUT)

environment = 'development'
db_config = YAML::load(File.open(File.expand_path('../../config/database.yml', __FILE__)))[environment]
ActiveRecord::Base.establish_connection(db_config)