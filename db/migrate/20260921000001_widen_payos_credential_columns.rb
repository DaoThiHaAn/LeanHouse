# Widen payos credential columns from string (VARCHAR 255) to text (unlimited)
# because Rails Active Record Encryption stores ciphertext as JSON blobs
# that exceed the 255-character limit of string columns.
class WidenPayosCredentialColumns < ActiveRecord::Migration[8.1]
  def change
    change_column :bank_accounts, :payos_api_key,      :text
    change_column :bank_accounts, :payos_checksum_key, :text
    change_column :bank_accounts, :payos_client_id,    :text
  end
end
