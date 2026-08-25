# Send notification to landlord and tenant in the date before 30 days
#  until the due date of the contract
class ContractDueReminderJob < ApplicationJob
  queue_as :default

  def perform
    target_date = Date.current + 30.days

    Contract.unfinished
            .where(due_date: target_date)
            .includes(tenant: :user, landlord: :user, house: {})
            .find_each do |contract|
      recipients = [ contract.tenant.user, contract.landlord.user ].compact.uniq

      ContractExpiringSoonNotifier.with(
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
