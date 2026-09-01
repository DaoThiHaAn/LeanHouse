class VietqrService
  # Templates supported by VietQR: 'compact', 'compact2', 'qr_only', 'print'
  def self.generate_url(bank_account:, amount:, description:, template: "compact2")
    return nil if bank_account.blank? || bank_account.bank.blank?

    bin = bank_account.bank.bin
    acc_num = bank_account.account_number
    acc_name = ERB::Util.url_encode(bank_account.account_holder.to_s.upcase)
    add_info = ERB::Util.url_encode(description.to_s)
    amt = amount.to_i

    "https://img.vietqr.io/image/#{bin}-#{acc_num}-#{template}.png?amount=#{amt}&addInfo=#{add_info}&accountName=#{acc_name}"
  end
end
