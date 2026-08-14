class RenameCheckoutToCheckedOutAtOnTenantStays < ActiveRecord::Migration[8.0]
  def change
    rename_column :tenant_stays, :check_out, :checkout_at
    rename_column :tenant_stays, :check_in, :checkin_at
    remove_column :tenant_stays, :created_at
    remove_column :tenant_stays, :updated_at
  end
end
