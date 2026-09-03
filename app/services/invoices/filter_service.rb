# frozen_string_literal: true

module Invoices
  class FilterService
    def self.call(...)
      new(...).call
    end

    def initialize(house:, params:, billing_month:, current_tenants_only: true)
      @house = house
      @params = params
      @billing_month = billing_month
      @current_tenants_only = current_tenants_only
    end

    def call
      scope = house.invoices
                   .for_month(billing_month)
                   .includes(:tenant, :bank_account, :created_by, room: :floor)
                   .sorted

      scope = filter_by_current_tenants(scope) if current_tenants_only
      scope = scope.where(status: params[:status]) if status_valid?
      scope = scope.where(invoice_type: params[:invoice_type]) if type_valid?
      scope = scope.joins(:room).where(rooms: { floor_id: params[:floor_id] }) if params[:floor_id].present?
      scope = scope.where(room_id: params[:room_id]) if params[:room_id].present?

      scope
    end

    private

    attr_reader :house, :params, :billing_month, :current_tenants_only

    def filter_by_current_tenants(scope)
      active_tenant_ids = house.currently_linked_tenant_ids
      occupied_room_ids = house.rooms.occupied.pluck(:id)

      scope.where(
        "(invoices.invoice_type = 'room' AND invoices.room_id IN (:room_ids)) OR (invoices.invoice_type = 'individual' AND invoices.tenant_id IN (:tenant_ids))",
        room_ids: occupied_room_ids.presence || [ 0 ],
        tenant_ids: active_tenant_ids.presence || [ 0 ]
      )
    end

    def status_valid?
      params[:status].present? && Invoice.statuses.key?(params[:status])
    end

    def type_valid?
      params[:invoice_type].present? && Invoice.invoice_types.key?(params[:invoice_type])
    end
  end
end
