class ContractClosing
  def self.call(...)
    new(...).call
  end

  # Batch close all overdue unfinished contracts matching the scope.
  def self.close_overdue!(scope = Contract.unfinished.where("contracts.due_date < ?", Date.current), send_noti: true)
    scope.includes(tenant: :user, landlord: :user, house: {}).find_each do |contract|
      close_if_overdue!(contract, send_noti: send_noti)
    end
  end

  # Auto-close a contract if it is unfinished and overdue as of reference_date.
  # Sets end_date to due_date and unlinks has_contract on the active stay.
  def self.close_if_overdue!(contract, reference_date = Date.current, send_noti: false)
    contract.reload
    return false if contract.finished?
    return false unless contract.due_date < reference_date

    new(
      house: contract.house,
      contract: contract,
      end_date: contract.due_date,
      send_noti: send_noti,
      overdue: true
    ).call

    true
  end

  def initialize(house:, contract:, remove_tenant: false, end_date: nil, send_noti: true, overdue: false)
    @house = house
    @contract = contract
    @remove_tenant = remove_tenant
    @end_date = end_date || Date.current
    @send_noti = send_noti
    @overdue = overdue
  end

  def call
    tenant_stay = house.tenant_stay_for(contract.tenant_id)

    Contract.transaction do
      # 1. Close contract (soft completion by setting end_date)
      contract.update!(end_date: @end_date)

      tenant_stay&.update!(has_contract: false)

      # 2. If remove_tenant is checked, checkout the tenant stay
      if @remove_tenant && tenant_stay
        pending = Checkout.pending_invoices_for(
          house: house,
          tenant: tenant_stay.tenant,
          room: tenant_stay.rental_unit&.room
        )
        if pending.any?
          raise Checkout::PendingInvoicesError.new(pending)
        end

        tenant_stay.update!(checkout_at: Time.current)
        tenant_stay.rental_unit.tenant_removed! # Decrements room.tenants_count, frees up bed
      end
    end

    # 3. Send contract closed notifications if enabled
    if @send_noti
      if @overdue
        send_overdue_closed_notifications
      else
        send_contract_closed_notifications
      end
    end

    # 4. If tenant was also removed from the house, send tenant removed notifications to Landlord and Tenant
    if @remove_tenant && tenant_stay
      send_tenant_removed_notifications(tenant_stay)
    end

    contract
  end

  private

  attr_reader :house, :contract

  def send_overdue_closed_notifications
    recipients = [ contract.tenant&.user, contract.landlord&.user ].compact.uniq
    return if recipients.empty?

    ContractOverdueClosedNotifier.with(
      contract: contract,
      contract_id: contract.id,
      contract_name: contract.name,
      tenant_name: contract.tenant&.user&.fullname,
      due_date: contract.due_date.strftime("%d/%m/%Y"),
      house_id: house.id
    ).deliver_later(recipients)
  end

  def send_contract_closed_notifications
    recipients = [ contract.tenant.user ].compact

    ContractClosedNotifier.with(
      contract: contract,
      contract_id: contract.id,
      contract_name: contract.name,
      tenant_name: contract.tenant.user.fullname,
      house_id: house.id
    ).deliver_later(recipients) if recipients.any?
  end

  def send_tenant_removed_notifications(tenant_stay)
    rental_unit = tenant_stay.rental_unit
    recipients = [ tenant_stay.tenant.user ].compact

    TenantRemovedNotifier.with(
      tenant_stay: tenant_stay,
      house_id: house.id,
      house: house.name,
      floor: rental_unit.floor.name,
      rental_unit: rental_unit.title_name,
      tenant_name: tenant_stay.tenant.user.fullname
    ).deliver_later(recipients) if recipients.any?
  end
end
