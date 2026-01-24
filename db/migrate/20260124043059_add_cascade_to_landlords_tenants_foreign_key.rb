class AddCascadeToLandlordsTenantsForeignKey < ActiveRecord::Migration[8.0]
  def change
    # remove existing foreign key
    remove_foreign_key :landlords, column: :id

    # re-add with cascade
    add_foreign_key :landlords, :users,
      column: :id,
      on_delete: :cascade

    # remove existing foreign key
    remove_foreign_key :tenants, column: :id

    # re-add with cascade
    add_foreign_key :tenants, :users,
      column: :id,
      on_delete: :cascade
  end
end
