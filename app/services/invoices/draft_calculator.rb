module Invoices
  class DraftCalculator
    attr_reader :room, :billing_month, :invoice_type, :tenant, :house

    def initialize(room:, billing_month:, invoice_type: "room", tenant: nil)
      @room = room
      @house = room.house
      @billing_month = billing_month.to_date.beginning_of_month
      @invoice_type = invoice_type.to_s
      @tenant = tenant
    end

    def build_items
      items = []

      # 1. Rent Line Item
      items << build_rent_item

      # 2. Fixed Services Line Items
      items.concat(build_fixed_service_items)

      # 3. Metered Services Line Items
      items.concat(build_metered_service_items)

      items.compact
    end

    private

    def active_tenants_count
      @active_tenants_count ||= [ room.tenants_count, 1 ].max
    end

    def build_rent_item
      if invoice_type == "individual" && tenant.present?
        stay = house.tenant_stay_for(tenant.id)
        rent_amount = stay&.rental_unit&.rent || 0
        location = stay&.rental_unit&.location_info || room.title_name
        {
          item_type: :rent,
          name: "Tiền thuê #{location}",
          unit: "tháng",
          unit_price: rent_amount,
          quantity: 1.0,
          amount: rent_amount,
          start_date: billing_month.beginning_of_month,
          end_date: billing_month.end_of_month,
          selected: true
        }
      else
        rent_amount = room.rental_unit&.rent || 0
        {
          item_type: :rent,
          name: "Tiền thuê #{room.title_name}",
          unit: "tháng",
          unit_price: rent_amount,
          quantity: 1.0,
          amount: rent_amount,
          start_date: billing_month.beginning_of_month,
          end_date: billing_month.end_of_month,
          selected: true
        }
      end
    end

    def build_fixed_service_items
      items = []
      room.room_services.includes(service_variant: :service).each do |rs|
        variant = rs.service_variant
        next if variant.is_real_time?

        qty = calculate_fixed_quantity(variant)
        price = variant.fee
        amount = (qty * price).round

        items << {
          service_variant_id: variant.id,
          item_type: :fixed_service,
          name: variant.service.name,
          unit: variant.human_unit,
          unit_price: price,
          quantity: qty,
          amount: amount,
          start_date: billing_month.beginning_of_month,
          end_date: billing_month.end_of_month,
          selected: true
        }
      end
      items
    end

    def calculate_fixed_quantity(variant)
      case variant.unit.to_sym
      when :per_room, :per_month
        if invoice_type == "individual"
          (1.0 / active_tenants_count).round(2)
        else
          1.0
        end
      when :per_person
        if invoice_type == "individual"
          1.0
        else
          room.tenants_count.to_f
        end
      when :per_item
        if invoice_type == "individual" && tenant.present?
          room.house.vehicles.where(tenant_id: tenant.id).count.to_f
        else
          room.house.vehicles.where(tenant_id: room.tenants.pluck(:id)).count.to_f
        end
      else
        1.0
      end
    end

    def build_metered_service_items
      items = []
      room.service_variants.where(is_real_time: true).includes(:service).each do |variant|
        log = room.service_usage_logs.find_by(
          service_id: variant.service_id,
          billing_month: billing_month
        )

        prev_num = log&.prev_reading || previous_month_reading(variant.service_id)
        latest_num = log&.latest_reading
        has_log = log.present?
        is_confirmed = log&.is_confirmed? || false

        total_usage = (latest_num && prev_num) ? [ latest_num - prev_num, 0 ].max : 0
        divisor = (invoice_type == "individual") ? active_tenants_count : 1
        qty = (total_usage.to_f / divisor).round(2)
        amount = (qty * variant.fee).round

        items << {
          service_variant_id: variant.id,
          service_usage_log_id: log&.id,
          item_type: :metered_service,
          name: variant.service.name,
          unit: variant.human_unit,
          unit_price: variant.fee,
          prev_reading: prev_num,
          latest_reading: latest_num,
          is_confirmed: is_confirmed,
          has_log: has_log,
          quantity: qty,
          amount: amount,
          start_date: log&.start_date || billing_month.beginning_of_month,
          end_date: log&.end_date || billing_month.end_of_month,
          selected: true
        }
      end
      items
    end

    def previous_month_reading(service_id)
      room.service_usage_logs
          .where(service_id: service_id)
          .where("billing_month < ?", billing_month)
          .order(billing_month: :desc)
          .pick(:latest_reading) || 0
    end
  end
end
