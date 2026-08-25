class ContractExtension
  def self.call(...)
    new(...).call
  end

  def initialize(house:, contract:, params:, send_noti: true)
    @house = house
    @contract = contract
    @params = params
    @send_noti = send_noti
  end

  def call
    new_due_date = parse_due_date(params[:due_date])
    old_due_date = contract.due_date

    if new_due_date.blank?
      contract.errors.add(:due_date, :blank)
      raise ActiveRecord::RecordInvalid.new(contract)
    end

    if old_due_date.present? && new_due_date <= old_due_date
      contract.errors.add(:due_date, :must_be_after_current_due_date)
      raise ActiveRecord::RecordInvalid.new(contract)
    end

    Contract.transaction do
      contract.update!(due_date: new_due_date, end_date: nil)
    end

    send_notifications(contract) if @send_noti

    contract
  end

  private

  attr_reader :house, :contract, :params

  def parse_due_date(val)
    return val if val.is_a?(Date)
    Date.parse(val.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def send_notifications(contract)
    recipients = [ contract.tenant.user, contract.landlord.user ].compact.uniq

    ContractExtendedNotifier.with(
      contract: contract,
      contract_id: contract.id,
      contract_name: contract.name,
      tenant_name: contract.tenant.user.fullname,
      due_date: contract.due_date,
      house_id: house.id
    ).deliver_later(recipients)
  end
end
