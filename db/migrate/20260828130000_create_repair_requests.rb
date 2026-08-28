class CreateRepairRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :repair_requests do |t|
      t.string :title, null: false
      t.text :content, null: false

      t.timestamps
    end
  end
end
