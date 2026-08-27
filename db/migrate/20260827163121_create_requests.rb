class CreateRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :requests do |t|
      t.references :tenant, null: false, foreign_key: { on_delete: :cascade }
      t.references :house, null: false, foreign_key: { on_delete: :cascade }

      t.string :requestable_type, null: false
      t.bigint :requestable_id, null: false

      t.string :status, null: false, default: "pending"
      t.string :rejection_reason

      t.references :resolved_by,
                   null: true,
                   foreign_key: { to_table: :users }

      t.datetime :resolved_at

      t.timestamps
    end

    add_index :requests,
              [ :requestable_type, :requestable_id ],
              unique: true
  end
end
