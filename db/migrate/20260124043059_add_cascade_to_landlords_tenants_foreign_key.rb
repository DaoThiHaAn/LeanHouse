class AddCascadeToLandlordsTenantsForeignKey < ActiveRecord::Migration[8.0]
  def change
    # Pass the destination table (:users) so Rails can invert this during rollback
    remove_foreign_key :landlords, :users, column: :id
    add_foreign_key :landlords, :users, column: :id, on_delete: :cascade

    remove_foreign_key :tenants, :users, column: :id
    add_foreign_key :tenants, :users, column: :id, on_delete: :cascade
  end
end
