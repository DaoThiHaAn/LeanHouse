# frozen_string_literal: true

class AccountDeletionCheck
  Result = Struct.new(:can_delete, :blockers, keyword_init: true) do
    def can_delete?
      can_delete == true
    end
  end

  Blocker = Struct.new(:key, :count, keyword_init: true)

  def self.call(user)
    new(user).call
  end

  def initialize(user)
    @user = user
  end

  def call
    return Result.new(can_delete: false, blockers: []) unless @user

    blockers = if @user.landlord?
      check_landlord
    elsif @user.tenant?
      check_tenant
    else
      []
    end

    Result.new(
      can_delete: blockers.empty?,
      blockers: blockers
    )
  end

  private

  attr_reader :user

  def check_landlord
    blockers = []
    landlord = user.landlord
    return blockers unless landlord

    active_houses = landlord.houses.where(is_deleted: false)

    # 1. Active occupants across undeleted houses
    occupants_count = Room.joins(:floor)
                          .where(floors: { house_id: active_houses.select(:id) })
                          .where("rooms.tenants_count > 0")
                          .sum("rooms.tenants_count")
    if occupants_count > 0
      blockers << Blocker.new(key: :active_tenants, count: occupants_count)
    end

    # 2. Pending or in-handling service/maintenance requests
    pending_requests_count = Request.where(house_id: active_houses.select(:id), status: %i[pending handling]).count
    if pending_requests_count > 0
      blockers << Blocker.new(key: :pending_requests, count: pending_requests_count)
    end

    # 3. Unpaid invoices (pending or overdue) across all houses
    unpaid_invoices_count = Invoice.where(house_id: active_houses.select(:id), status: %w[pending overdue]).count
    if unpaid_invoices_count > 0
      blockers << Blocker.new(key: :unpaid_invoices, count: unpaid_invoices_count)
    end

    blockers
  end

  def check_tenant
    blockers = []
    tenant = user.tenant
    return blockers unless tenant

    # 1. Active stay in a rental unit
    if tenant.linked?
      blockers << Blocker.new(key: :active_stay, count: 1)
    end

    # 2. Pending or in-progress requests submitted by tenant
    pending_requests_count = tenant.requests.where(status: %i[pending handling]).count
    if pending_requests_count > 0
      blockers << Blocker.new(key: :pending_requests, count: pending_requests_count)
    end

    # 3. Unpaid invoices tied to tenant
    unpaid_invoices_count = Invoice.where(tenant_id: user.id, status: %w[pending overdue]).count
    if unpaid_invoices_count > 0
      blockers << Blocker.new(key: :unpaid_invoices, count: unpaid_invoices_count)
    end

    blockers
  end
end
