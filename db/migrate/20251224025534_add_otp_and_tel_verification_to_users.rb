class AddOtpAndTelVerificationToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :otp_code, :string
    add_column :users, :otp_sent_at, :datetime
    add_column :users, :tel_verified_at, :datetime
    add_column :users, :role, :string
    add_column :users, :discarded_at, :datetime

    add_index :users, [ :tel, :role ], unique: true, where: "discarded_at IS NULL"
  end
end
