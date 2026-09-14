module LandlordDashboard
  class TenantFlowCalculator
    def self.call(...)
      new(...).call
    end

    def initialize(target_houses, target_date = Date.current)
      @target_houses = target_houses
      @target_date = target_date
      @month_start = target_date.beginning_of_month.beginning_of_day
      @month_end = target_date.end_of_month.end_of_day
    end

    def call
      house_ids = target_houses.select(:id)
      return { new_tenants: 0, leaved_tenants: 0 } if house_ids.empty?

      base_scope = TenantStay.joins(
        "INNER JOIN rental_units ON rental_units.id = tenant_stays.rental_unit_id
         LEFT JOIN rooms r_direct ON rental_units.rentable_type = 'Room' AND r_direct.id = rental_units.rentable_id
         LEFT JOIN beds b ON rental_units.rentable_type = 'Bed' AND b.id = rental_units.rentable_id
         LEFT JOIN rooms r_bed ON b.room_id = r_bed.id
         INNER JOIN floors ON floors.id = COALESCE(r_direct.floor_id, r_bed.floor_id)"
      ).where(floors: { house_id: house_ids })

      # Unique new tenants: checked in this month and was not already staying before month_start
      existing_tenant_ids = base_scope.where("tenant_stays.checkin_at < ?", month_start)
                                       .where("tenant_stays.checkout_at IS NULL OR tenant_stays.checkout_at >= ?", month_start)
                                       .select(:tenant_id)

      new_tenants_count = base_scope.where(tenant_stays: { checkin_at: month_start..month_end })
                                    .where.not(tenant_id: existing_tenant_ids)
                                    .select(:tenant_id)
                                    .distinct
                                    .count

      # Unique leaved tenants: checked out this month and does not have an active stay remaining in this house
      active_tenant_ids = base_scope.where(tenant_stays: { checkout_at: nil })
                                    .select(:tenant_id)

      leaved_tenants_count = base_scope.where(tenant_stays: { checkout_at: month_start..month_end })
                                       .where.not(tenant_id: active_tenant_ids)
                                       .select(:tenant_id)
                                       .distinct
                                       .count

      {
        new_tenants: new_tenants_count,
        leaved_tenants: leaved_tenants_count
      }
    end

    private

    attr_reader :target_houses, :target_date, :month_start, :month_end
  end
end
