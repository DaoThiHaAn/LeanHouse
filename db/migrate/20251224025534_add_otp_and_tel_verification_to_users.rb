class AddOtpAndTelVerificationToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :otp_code, :string
    add_column :users, :otp_sent_at, :datetime
    add_column :users, :tel_verified, :boolean
    add_column :users, :role, :string
  end
end
