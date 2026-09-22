# Remove a tenant from a rental unit
class Checkout
  class PendingInvoicesError < StandardError
    attr_reader :invoices

    def initialize(invoices = [])
      @invoices = invoices
      super(I18n.t("errors.tenant_has_pending_invoices", count: invoices.size))
    end
  end

  def self.call(...)
    new(...).call
  end

  def self.pending_invoices_for(house:, tenant:, room: nil)
    unpaid_scope = house.invoices.kept.where(status: %w[pending overdue])
    tenant_unpaid_ids = unpaid_scope.where(tenant_id: tenant.id).pluck(:id)

    room_unpaid_ids = if room.present? && room.active_staying_tenant_users.count <= 1
                        unpaid_scope.where(room_id: room.id, invoice_type: "room").pluck(:id)
    else
                        []
    end

    all_unpaid_ids = (tenant_unpaid_ids + room_unpaid_ids).uniq
    house.invoices.where(id: all_unpaid_ids)
  end

  def initialize(house:, tenant_stay:, end_contract: true, send_noti: true, approved_request: nil)
    @house = house
    @tenant_stay = tenant_stay
    @end_contract = end_contract
    @send_noti = send_noti
    @approved_request = approved_request
  end

  def call
    pending = self.class.pending_invoices_for(
      house: house,
      tenant: tenant_stay.tenant,
      room: tenant_stay.rental_unit&.room
    )
    if pending.any?
      raise PendingInvoicesError.new(pending)
    end

    TenantStay.transaction do
      auto_resolve_pending_requests!
      checkout_stay!
      tenant_stay.rental_unit.tenant_removed!  # Update occupancy
      end_contract! if @end_contract
      remove_vehicles!
    end

    send_notification if @send_noti
    tenant_stay
  end

  private

  attr_reader :tenant_stay, :house

  def auto_resolve_pending_requests!
    landlord_user = house.landlord.user
    rejection_reason = I18n.t("request.rejection_reason_checkout", default: "Khách thuê đã trả phòng / rời nhà.")

    house.requests.where(tenant_id: tenant_stay.tenant_id, status: %i[pending handling]).find_each do |req|
      if @approved_request.present? && req.id == @approved_request.id
        req.update!(
          status: :approved,
          resolved_by: landlord_user,
          resolved_at: Time.current
        )
      else
        if req.requestable.respond_to?(:reject!) && req.actionable?
          req.requestable.reject!(landlord_user, rejection_reason)
        else
          req.update!(
            status: :rejected,
            rejection_reason: rejection_reason,
            resolved_by: landlord_user,
            resolved_at: Time.current
          )
          req.requestable.try(:purge_documents!)
        end
      end
    end
  end
  alias_method :auto_approve_pending_requests!, :auto_resolve_pending_requests!

  # Update the checkout time
  def checkout_stay!
    tenant_stay.update!(
      checkout_at: Time.current
    )
  end

  def end_contract!
    contract = house.contracts.unfinished.find_by(tenant_id: tenant_stay.tenant_id)
    if contract
      contract.update!(end_date: Date.current)
      tenant_stay.update!(has_contract: false)
    end
  end

  def remove_vehicles!
    house.vehicles.where(tenant_id: tenant_stay.tenant_id).destroy_all
  end

  def send_notification
    rental_unit = tenant_stay.rental_unit
    recipients = [ tenant_stay.tenant.user, house.landlord.user ].compact.uniq

    TenantRemovedNotifier.with(
      tenant_stay: tenant_stay,
      house_id: house.id,
      house: house.name,
      floor: rental_unit.floor.name,
      rental_unit: rental_unit.title_name,
      tenant_name: tenant_stay.tenant.user.fullname
    ).deliver_later(recipients)
  end
end
