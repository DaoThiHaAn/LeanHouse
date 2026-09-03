# frozen_string_literal: true

module Invoices
  class FilterService
    def self.call(...)
      new(...).call
    end

    def initialize(house:, params: {}, billing_month: nil, current_tenants_only: false, tenant: nil, tenant_room_ids: nil)
      @house = house
      @params = params || {}
      @billing_month = billing_month
      @current_tenants_only = current_tenants_only
      @tenant = tenant
      @tenant_room_ids = tenant_room_ids
    end

    def call
      scope = house.invoices.kept

      scope = filter_by_tenant(scope) if tenant.present?
      scope = filter_by_current_tenants(scope) if current_tenants_only

      month = target_billing_month
      scope = scope.for_month(month) if month.present?

      scope = apply_search(scope)
      scope = scope.where(status: params[:status]) if status_valid?
      scope = scope.where(invoice_type: params[:invoice_type]) if type_valid?
      scope = scope.joins(:room).where(rooms: { floor_id: params[:floor_id] }) if params[:floor_id].present?
      scope = scope.where(room_id: params[:room_id]) if params[:room_id].present?

      scope
        .includes(:tenant, :bank_account, :created_by, room: :floor)
        .sorted
    end

    private

    attr_reader :house, :params, :billing_month, :current_tenants_only, :tenant, :tenant_room_ids

    def filter_by_tenant(scope)
      room_ids = tenant_room_ids || []
      scope.where(
        "(invoices.invoice_type = 'room' AND invoices.room_id IN (:room_ids)) OR (invoices.invoice_type = 'individual' AND invoices.tenant_id = :tenant_id)",
        room_ids: room_ids,
        tenant_id: tenant.id
      )
    end

    def filter_by_current_tenants(scope)
      active_tenant_ids = house.currently_linked_tenant_ids
      occupied_room_ids = house.rooms.occupied.pluck(:id)

      scope.where(
        "(invoices.invoice_type = 'room' AND invoices.room_id IN (:room_ids)) OR (invoices.invoice_type = 'individual' AND invoices.tenant_id IN (:tenant_ids))",
        room_ids: occupied_room_ids.presence || [ 0 ],
        tenant_ids: active_tenant_ids.presence || [ 0 ]
      )
    end

    def target_billing_month
      return billing_month if billing_month.present?
      return if params[:month].blank?

      Date.parse("#{params[:month]}-01")
    rescue StandardError
      Date.parse(params[:month].to_s) rescue nil
    end

    def apply_search(scope)
      query = (params[:q] || params[:query])&.strip
      return scope if query.blank?

      q = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      scope.where("invoices.code ILIKE :q OR invoices.title ILIKE :q", q: q)
    end

    def status_valid?
      params[:status].present? && Invoice.statuses.key?(params[:status])
    end

    def type_valid?
      params[:invoice_type].present? && Invoice.invoice_types.key?(params[:invoice_type])
    end
  end
end
