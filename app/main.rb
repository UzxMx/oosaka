#!/usr/bin/env ruby

require 'bundler/setup'

Bundler.require(:default)

require './osk'
require './osk/server'
require 'optparse'
require 'logger'

class Main
	include Osk

	def parse_arguments(arguments)
		options = {}

		OptionParser.new do |opt|
			opt.banner = "Usage: ruby main.rb [options]"
			opt.on("-e", "--environment=name", String, "Specifies the environment to run servers under (development/production).", "Default: development") { |v| options[:environment] = v.strip }

			opt.parse!(arguments)
		end

		options
	end

	def main
		options = parse_arguments(ARGV)

		Osk.logger = Logger.new(STDOUT)
		Osk.logger.level = Logger::DEBUG

		if ENV['HOME'].nil? or ENV['HOME'].length == 0
			raise 'HOME environment not set'
		end
		Osk.logs_dir = File.join(ENV['HOME'], 'oosaka', 'logs')

		ActiveRecord::Base.logger = Osk.logger

		# ActiveRecord::Base.default_timezone = 'Beijing'

		if options[:environment]
			environment = options[:environment]
		else
			environment = 'development'
		end

		db_config = YAML::load(File.open(File.expand_path('../../config/database.yml', __FILE__)))[environment]
		ActiveRecord::Base.establish_connection(db_config)

		EventMachine.run {
			EventMachine.start_server("0.0.0.0", 8081, Osk::AppConnection)

			logger.info 'app server running...'

			Thread.new {
				EventMachine.run {
					EventMachine.start_server("127.0.0.1", 8082, Osk::MonitorConnection)

					logger.info 'monitor server running...'
				}
			}
		}
	end
end

Main.new.main
