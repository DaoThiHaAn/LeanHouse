class ContractSigning
  def self.call(...)
    new(...).call
  end

  def initialize(house:, tenant_stay:, landlord:, params:, send_noti: true)
    @house = house
    @tenant_stay = tenant_stay
    @landlord = landlord
    @params = params
    @send_noti = send_noti
  end

  def call
    contract = house.contracts.build(
      params.merge(
        tenant: tenant_stay.tenant,
        landlord: landlord
      )
    )

    Contract.transaction do
      contract.save!
      tenant_stay.update!(has_contract: true)
    end

    send_notifications(contract) if @send_noti

    contract
  end

  private

  attr_reader :house, :tenant_stay, :landlord, :params

  def send_notifications(contract)
    # Gửi cho cả khách thuê và chủ nhà
    recipients = [ tenant_stay.tenant.user, landlord.user ].compact.uniq

    ContractSignedNotifier.with(
      contract: contract,
      contract_name: contract.name,
      tenant_name: tenant_stay.tenant.user.fullname,
      house_id: house.id
    ).deliver_later(recipients)
  end
end
