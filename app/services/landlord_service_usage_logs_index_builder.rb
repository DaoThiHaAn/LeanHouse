# frozen_string_literal: true

class LandlordServiceUsageLogsIndexBuilder
  IndexData = Data.define(
    :unconfirmed_count,
    :fixed_services_count,
    :current_tab,
    :fixed_services_summary,
    :fixed_services,
    :fixed_variants,
    :logs,
    :services,
    :service_variants
  ) do
    def initialize(
      unconfirmed_count:,
      fixed_services_count:,
      current_tab:,
      fixed_services_summary: nil,
      fixed_services: nil,
      fixed_variants: nil,
      logs: nil,
      services: nil,
      service_variants: nil
    )
      super
    end
  end

  FormOptions = Data.define(
    :rooms,
    :floors,
    :room_options,
    :room_real_time_variant_ids,
    :room_occupancy
  )

  class << self
    def parse_month(str)
      return Date.current.beginning_of_month if str.blank?

      str_val = str.to_s.strip
      if (m = str_val.match(/\A(\d{4})[-.\/](\d{1,2})\z/))
        year = m[1].to_i
        month = m[2].to_i
        return Date.new(year, month, 1) if month.between?(1, 12) && year.between?(2000, 2100)
      end

      begin
        Date.parse("#{str_val}-01").beginning_of_month
      rescue StandardError
        Date.current.beginning_of_month
      end
    end

    def for_house(house:, billing_month:, params:)
      unconfirmed_count = house.service_usage_logs.for_month(billing_month).unconfirmed.count
      fixed_services_count = RoomService
        .where(room_id: house.rooms.select(:id))
        .joins(:service_variant)
        .where(service_variants: { is_real_time: false })
        .count
      current_tab = params[:tab] == "fixed" ? "fixed" : "real_time"

      if current_tab == "fixed"
        IndexData.new(
          unconfirmed_count: unconfirmed_count,
          fixed_services_count: fixed_services_count,
          current_tab: current_tab,
          fixed_services_summary: HouseFixedServicesSummary.call(house: house, billing_month: billing_month, params: params),
          fixed_services: house.services.joins(:service_variants).where(service_variants: { is_real_time: false }).distinct.name_sorted,
          fixed_variants: house.service_variants.where(is_real_time: false)
        )
      else
        IndexData.new(
          unconfirmed_count: unconfirmed_count,
          fixed_services_count: fixed_services_count,
          current_tab: current_tab,
          logs: LandlordServiceUsageLogsFilter.call(house: house, params: params.reverse_merge(month: billing_month.strftime("%Y-%m"))),
          services: house.services.joins(:service_variants).where(service_variants: { is_real_time: true }).distinct.name_sorted
        )
      end
    end

    def for_room(house:, room:, billing_month:, params:)
      unconfirmed_count = room.service_usage_logs.unconfirmed.count
      fixed_services_count = room.room_services.joins(:service_variant).where(service_variants: { is_real_time: false }).count
      current_tab = if params[:tab].present?
        params[:tab] == "fixed" ? "fixed" : "real_time"
      elsif room.service_variants.any?(&:is_real_time?)
        "real_time"
      elsif fixed_services_count.positive?
        "fixed"
      else
        "real_time"
      end

      if current_tab == "fixed"
        IndexData.new(
          unconfirmed_count: unconfirmed_count,
          fixed_services_count: fixed_services_count,
          current_tab: current_tab,
          fixed_services_summary: RoomFixedServicesSummary.call(
            room: room,
            billing_month: billing_month,
            page: params[:page],
            per_page: params[:per_page]
          )
        )
      else
        IndexData.new(
          unconfirmed_count: unconfirmed_count,
          fixed_services_count: fixed_services_count,
          current_tab: current_tab,
          logs: LandlordServiceUsageLogsFilter.call(house: house, room: room, params: params),
          services: house.services.name_sorted
        )
      end
    end

    def for_service(house:, service:, billing_month:, params:)
      unconfirmed_count = house.service_usage_logs.for_month(billing_month).where(service_id: service.id).unconfirmed.count
      fixed_services_count = RoomService
        .where(room_id: house.rooms.select(:id))
        .joins(:service_variant)
        .where(service_variants: { service_id: service.id, is_real_time: false })
        .count

      current_tab = if params[:tab].present?
        params[:tab] == "fixed" ? "fixed" : "real_time"
      elsif service.service_variants.any?(&:is_real_time?)
        "real_time"
      else
        "fixed"
      end

      if current_tab == "fixed"
        IndexData.new(
          unconfirmed_count: unconfirmed_count,
          fixed_services_count: fixed_services_count,
          current_tab: current_tab,
          fixed_services_summary: HouseFixedServicesSummary.call(
            house: house,
            billing_month: billing_month,
            params: params.merge(service_id: service.id)
          ),
          fixed_services: [ service ],
          fixed_variants: service.service_variants.where(is_real_time: false)
        )
      else
        IndexData.new(
          unconfirmed_count: unconfirmed_count,
          fixed_services_count: fixed_services_count,
          current_tab: current_tab,
          logs: LandlordServiceUsageLogsFilter.call(
            house: house,
            params: params.reverse_merge(month: billing_month.strftime("%Y-%m"), service_id: service.id)
          ),
          service_variants: service.service_variants.where(is_real_time: true)
        )
      end
    end

    def floor_and_room_options(house:)
      rooms = house.rooms.active.includes(:floor, :service_variants).sorted
      floors = rooms.map(&:floor).compact.uniq.sort_by(&:position)
      room_options = rooms.map do |r|
        {
          id: r.id,
          floorId: r.floor_id,
          name: r.title_name
        }
      end
      room_real_time_variant_ids = rooms.each_with_object({}) do |r, h|
        h[r.id.to_s] = r.service_variants.select(&:is_real_time?).map { |v| v.id.to_s }
      end
      room_occupancy = rooms.each_with_object({}) do |r, h|
        h[r.id.to_s] = !r.empty?
      end

      FormOptions.new(
        rooms: rooms,
        floors: floors,
        room_options: room_options,
        room_real_time_variant_ids: room_real_time_variant_ids,
        room_occupancy: room_occupancy
      )
    end
  end
end
