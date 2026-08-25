class ContractRenewal
  def self.call(...)
    new(...).call
  end

  def initialize(house:, old_contract:, tenant_stay:, landlord:, params:, send_noti: true)
    @house = house
    @old_contract = old_contract
    @tenant_stay = tenant_stay
    @landlord = landlord
    @params = params
    @send_noti = send_noti
  end

  def call
    new_contract = house.contracts.build(
      params.merge(
        tenant: tenant_stay.tenant,
        landlord: landlord
      )
    )

    Contract.transaction do
      # 1. Close the old contract if it is not already closed
      if old_contract.present? && old_contract.end_date.blank?
        old_contract.update!(end_date: Date.current)
      end

      # 2. Save the new contract and ensure tenant_stay has_contract is true
      new_contract.save!
      tenant_stay.update!(has_contract: true)
    end

    send_notifications(new_contract) if @send_noti

    new_contract
  end

  private

  attr_reader :house, :old_contract, :tenant_stay, :landlord, :params

  def send_notifications(contract)
    recipients = [ tenant_stay.tenant.user, landlord.user ].compact.uniq

    ContractSignedNotifier.with(
      contract: contract,
      contract_name: contract.name,
      tenant_name: tenant_stay.tenant.user.fullname,
      house_id: house.id
    ).deliver_later(recipients)
  end
end
