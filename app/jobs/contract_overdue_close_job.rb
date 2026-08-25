class ContractOverdueCloseJob < ApplicationJob
  queue_as :default

  def perform
    Contract.unfinished
            .where("due_date < ?", Date.current)
            .includes(tenant: :user, landlord: :user, house: {})
            .find_each do |contract|
      Contract.transaction do
        contract.update!(end_date: contract.due_date)
        tenant_stay = contract.house.tenant_stay_for(contract.tenant_id)
        tenant_stay&.update!(has_contract: false)
      end

      recipients = [ contract.tenant.user, contract.landlord.user ].compact.uniq

      ContractOverdueClosedNotifier.with(
        contract: contract,
        contract_id: contract.id,
        contract_name: contract.name,
        tenant_name: contract.tenant.user.fullname,
        due_date: contract.due_date.strftime("%d/%m/%Y"),
        house_id: contract.house_id
      ).deliver_later(recipients)
    end
  end
end
