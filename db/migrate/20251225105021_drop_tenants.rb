class DropTenants < ActiveRecord::Migration[8.0]
  def change
    drop_table :tenants
  end
end
