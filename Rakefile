require 'bundler/setup'

Bundler.require(:default)

require 'yaml'

namespace :db do

	environment = 'development'
	db_config = YAML::load(File.open('config/database.yml'))[environment]

	desc "Create the database"
	task :create do
		begin
			if db_config['adapter'] == 'mysql'
				ActiveRecord::Base.establish_connection(db_config.merge('database' => nil))
			elsif db_config['adapter'] == 'postgresql'
				ActiveRecord::Base.establish_connection(db_config.merge('database' => 'postgres'))
			end
			
			ActiveRecord::Base.connection.create_database(db_config['database'])
			puts "Database created"
		rescue ActiveRecord::StatementInvalid => error
			if /database exists/ === error.message
				puts "Database already exists"
			else
				raise
			end
		end
	end

	desc "Drop the database"
	task :drop do
		if db_config['adapter'] == 'mysql'
			ActiveRecord::Base.establish_connection(db_config)
		elsif db_config['adapter'] == 'postgresql'
			ActiveRecord::Base.establish_connection(db_config.merge('database' => 'postgres'))
		end		
		ActiveRecord::Base.connection.drop_database(db_config['database'])
		puts "Database dropped"
	end

	desc "Reset the database"
	task :reset => [:drop, :create, :migrate]

	desc "Migrate the database"
	task :migrate do
		ActiveRecord::Base.establish_connection(db_config)
		ActiveRecord::Migrator.migrate("db/migrate/")
		Rake::Task["db:_dump"].invoke
		puts "Database migrated"
	end

	desc 'Create a db/schema.rb file that is portable against any DB supported by AR'
	task :_dump do
		ActiveRecord::Base.establish_connection(db_config)
		require 'active_record/schema_dumper'
		filename = "db/schema.rb"
		File.open(filename, "w:utf-8") do |file|
			ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, file)
		end
	end

end

namespace :g do
	desc "Generate migration"
	task :migration do
		name = ARGV[1] || raise("Specify name: rake g:migration <migration_name>")
		timestamp = Time.now.strftime("%Y%m%d%H%M%S")
		path = File.expand_path("../db/migrate/#{timestamp}_#{name}.rb", __FILE__)
		migration_class = name.split("_").map(&:capitalize).join

		File.open(path, "w") do |file|
			file.write <<-EOF
class #{migration_class} < ActiveRecord::Migration
end
			EOF
		end

		puts "Migration #{path} created"
		abort # needed stop other tasks
	end
end