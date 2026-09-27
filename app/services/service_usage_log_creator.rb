# frozen_string_literal: true

class ServiceUsageLogCreator
  class << self
    def build_default(house:, room: nil, params: {})
      target_room = room || house.rooms.find_by(id: params[:room_id]) || house.rooms.active.first
      billing_month = LandlordServiceUsageLogsIndexBuilder.parse_month(params[:billing_month].presence || params[:month])
      service_variant = house.service_variants.where(is_real_time: true).find_by(id: params[:service_variant_id]) ||
                        house.service_variants.where(is_real_time: true).first

      prev_reading = if target_room && service_variant
        ServiceUsageLog.previous_reading_for(room: target_room, service_id: service_variant.service_id, before_month: billing_month)
      else
        0
      end

      ServiceUsageLog.new(
        room: target_room,
        service_variant: service_variant,
        service: service_variant&.service,
        service_name: service_variant ? service_variant.service.name : "Điện/Nước",
        unit: service_variant ? service_variant.human_unit : "kWh",
        unit_price: service_variant ? service_variant.fee : 0,
        billing_month: billing_month,
        start_date: billing_month.beginning_of_month,
        end_date: billing_month.end_of_month,
        prev_reading: prev_reading
      )
    end

    def call(log_params:, user:)
      log = ServiceUsageLog.new(log_params)
      # A vacant room has nobody to complete a pending reading. Keep this rule on
      # the server as well as in the form, so a crafted request cannot create one.
      log.is_confirmed = true if log.room&.empty?

      log.submitted_by = (log.is_confirmed? || log.latest_reading.present?) ? user : nil

      if log.is_confirmed?
        log.confirmed_by = user
        log.confirmed_at = Time.current
      else
        log.confirmed_by = nil
        log.confirmed_at = nil
      end

      if log.save
        notify_tenants_of_requested_log(log) unless log.is_confirmed?
      end

      log
    end

    private

    def notify_tenants_of_requested_log(log)
      tenants = log.room.active_staying_tenant_users
      return if tenants.empty?

      ServiceUsageLogRequestedNotifier.with(log: log).deliver_later(tenants)
    end
  end
end
