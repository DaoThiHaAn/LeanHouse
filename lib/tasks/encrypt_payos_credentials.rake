namespace :payos do
  desc "Encrypt existing plaintext PayOS credentials in bank_accounts table"
  task encrypt_existing: :environment do
    conn = ActiveRecord::Base.connection

    # Use raw SQL to get IDs — never load AR models, which would trigger decryption
    # on existing plaintext values and raise ActiveRecord::Encryption::Errors::Decryption.
    rows = conn.select_all("SELECT id, account_number FROM bank_accounts WHERE payos_enabled = true")

    if rows.empty?
      puts "No PayOS-enabled bank accounts found. Nothing to do."
      next
    end

    puts "Found #{rows.count} PayOS-enabled bank account(s). Encrypting credentials..."
    success_count = 0
    fail_count    = 0

    rows.each do |row|
      id      = row["id"]
      acc_num = row["account_number"]

      begin
        # Read plaintext via raw SQL — completely bypasses AR + encryption layer
        raw = conn.select_one(
          "SELECT payos_api_key, payos_checksum_key, payos_client_id
           FROM bank_accounts WHERE id = #{conn.quote(id)}"
        )

        # BankAccount.attribute_types["field"] returns EncryptedAttributeType for `encrypts` fields.
        # .serialize(plaintext_string) → encrypted JSON string (this is what gets stored in the DB).
        enc_api_key      = BankAccount.attribute_types["payos_api_key"].serialize(raw["payos_api_key"])
        enc_checksum_key = BankAccount.attribute_types["payos_checksum_key"].serialize(raw["payos_checksum_key"])
        enc_client_id    = BankAccount.attribute_types["payos_client_id"].serialize(raw["payos_client_id"])

        # Write back via raw SQL — no AR model load, no dirty tracking, no callbacks
        conn.execute(<<~SQL)
          UPDATE bank_accounts
          SET payos_api_key      = #{conn.quote(enc_api_key)},
              payos_checksum_key = #{conn.quote(enc_checksum_key)},
              payos_client_id    = #{conn.quote(enc_client_id)},
              updated_at         = NOW()
          WHERE id = #{conn.quote(id)}
        SQL

        puts "  ✓ Encrypted bank account ##{id} (#{acc_num})"
        success_count += 1
      rescue => e
        puts "  ✗ Failed for bank account ##{id}: #{e.message}"
        puts "     #{e.class}"
        fail_count += 1
      end
    end

    puts "\n#{success_count} encrypted, #{fail_count} failed."
    puts "\nNext step: set `support_unencrypted_data: false` in config/application.rb." if fail_count.zero?
  end
end
