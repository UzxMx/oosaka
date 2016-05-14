class CreateUsers < ActiveRecord::Migration
	def change
		create_table :users do |t|
			t.string :app_id, null: false
			t.string :device_id, null: false
			t.string :username
			t.boolean :online
			t.timestamps null: false
		end
	end
end
