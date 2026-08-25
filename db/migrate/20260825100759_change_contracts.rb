class ChangeContracts < ActiveRecord::Migration[8.0]
  def change
    rename_column :contracts, :citizen_id, :tenant_citizen_id
    add_column :contracts, :landlord_citizen_id, :string

    reversible do |dir|
      dir.up do
        Contract.reset_column_information
        Contract.update_all(landlord_citizen_id: "000000000000")
        change_column_null :contracts, :landlord_citizen_id, false
      end
    end
  end
end
