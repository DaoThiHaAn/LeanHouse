class CreateBanksAndBankAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :banks do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.string :bin, null: false
      t.string :short_name, null: false
      t.string :logo_url

      t.timestamps
    end

    add_index :banks, :bin, unique: true
    add_index :banks, :code, unique: true

    create_table :bank_accounts do |t|
      t.references :landlord, null: false, foreign_key: { on_delete: :cascade }
      t.references :bank, null: false, foreign_key: true
      t.string :account_number, null: false
      t.string :account_holder, null: false
      t.boolean :is_default, default: false, null: false

      t.timestamps
    end

    add_index :bank_accounts, [ :landlord_id, :account_number, :bank_id ], unique: true, name: "idx_unique_landlord_bank_acc"
  end
end
