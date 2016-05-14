class CreatePhoneDevices < ActiveRecord::Migration
	def change
		create_table :phone_devices do |t|
			t.belongs_to :user, index: true, null: false
			t.string :os
			t.string :manufacturer
			t.boolean :rooted
			t.string :locale
			t.string :app_version

			# instant info
			t.integer :network_type
			t.string :battery_info

			# log configuration
			t.integer :log_level
			t.integer :log_sent_freq

			t.datetime :fetched_at

			t.timestamps null: false
		end
	end
end
