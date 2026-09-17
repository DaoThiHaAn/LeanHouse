class VietqrService
  # Templates supported by VietQR: 'compact', 'compact2', 'qr_only', 'print'
  def self.generate_url(bank_account:, amount:, description:, template: "compact2")
    return nil if bank_account.blank? || bank_account.bank.blank?

    generate_raw_url(
      bin: bank_account.bank.bin,
      account_number: bank_account.account_number,
      account_holder: bank_account.account_holder,
      amount: amount,
      description: description,
      template: template
    )
  end

  def self.generate_raw_url(bin:, account_number:, account_holder:, amount:, description:, template: "compact2")
    return nil if bin.blank? || account_number.blank?

    acc_name = ERB::Util.url_encode(account_holder.to_s.upcase)
    add_info = ERB::Util.url_encode(description.to_s)
    amt = amount.to_i

    params = { amount: amt, accountName: acc_name }
    params[:addInfo] = add_info if description.present?

    query = params.map { |k, v| "#{k}=#{v}" }.join("&")
    "https://img.vietqr.io/image/#{bin}-#{account_number}-#{template}.png?#{query}"
  end
end
