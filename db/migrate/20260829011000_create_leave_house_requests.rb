class CreateLeaveHouseRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :leave_house_requests do |t|
      t.timestamps
    end
  end
end
