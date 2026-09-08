# frozen_string_literal: true

class RoomFixedServicesSummary
  DEFAULT_PER_PAGE = 10

  Item = Data.define(:service, :variant, :name, :unit, :unit_price, :quantity, :amount, :status, :invoice) do
    def initialize(service:, variant:, name:, unit:, unit_price:, quantity:, amount:, status:, invoice: nil)
      super(
        service: service,
        variant: variant,
        name: name,
        unit: unit,
        unit_price: unit_price,
        quantity: quantity,
        amount: amount,
        status: status,
        invoice: invoice
      )
    end

    def billed?
      status == :billed
    end

    def waived?
      status == :waived
    end

    def draft?
      status == :draft
    end

    def quantity_formatted
      quantity.to_s.sub(/\.0$/, "")
    end
  end

  attr_reader :room, :house, :billing_month, :page, :per_page, :tenant,
              :items, :paginated_items, :active_invoice, :active_invoices, :cancelled_invoices

  def self.call(...)
    new(...).call
  end

  def initialize(room:, billing_month: nil, page: nil, per_page: nil, tenant: nil)
    @room = room
    @house = room.house
    @billing_month = (billing_month || Date.current).beginning_of_month
    @page = page.presence || 1
    @per_page = per_page.presence || DEFAULT_PER_PAGE
    @tenant = tenant
    @items = []
  end

  def call
    load_invoices
    load_fixed_room_services
    build_items
    paginate_items
    self
  end

  def total_amount
    @total_amount ||= items.sum(&:amount)
  end

  def billing_month_str
    billing_month.strftime("%Y-%m")
  end

  def has_active_invoice?
    active_invoices.present?
  end

  def has_cancelled_invoices?
    cancelled_invoices.any?
  end

  def single_cancelled_invoice?
    cancelled_invoices.size == 1
  end

  def cancelled_invoice_codes
    cancelled_invoices.map(&:code).join(", ")
  end

  def cancelled_invoices_count
    cancelled_invoices.size
  end

  private

  attr_reader :fixed_room_services

  def load_invoices
    scope = room.invoices.for_month(billing_month)
    if tenant.present?
      scope = scope.where(
        "(invoices.invoice_type = 'room') OR (invoices.invoice_type = 'individual' AND invoices.tenant_id = :tenant_id)",
        tenant_id: tenant.id
      )
    end

    @active_invoices = scope.kept
                            .where(status: %w[pending paid overdue])
                            .includes(invoice_items: { service_variant: :service })
                            .order(created_at: :desc)
    @active_invoice = @active_invoices.first

    @cancelled_invoices = scope.where(status: :cancelled)
                               .order(updated_at: :desc)
  end

  def load_fixed_room_services
    @fixed_room_services = room.room_services
                               .joins(:service_variant)
                               .where(service_variants: { is_real_time: false })
                               .where("room_services.created_at <= ?", billing_month.end_of_month)
                               .includes(service_variant: :service)
  end

  def build_items
    if tenant_outside_stay?
      @items = []
      return
    end

    @items = if active_invoices.present?
               build_billed_items
    else
               build_draft_items
    end
  end

  def tenant_outside_stay?
    return false if tenant.blank?

    stay = tenant.tenant_stays.where(rental_unit: room.rental_unit).first
    return false if stay.blank?

    start_date = [ stay.checkin_at&.to_date, stay.contract&.start_date ].compact.min
    start_month = start_date&.beginning_of_month
    start_month.present? && billing_month < start_month
  end

  def build_billed_items
    all_invoice_fixed_items = @active_invoices.flat_map do |inv|
      inv.invoice_items.select(&:fixed_service?).map { |it| [ it, inv ] }
    end

    result = []

    fixed_room_services.each do |rs|
      variant = rs.service_variant
      matching_pairs = all_invoice_fixed_items.select { |(it, _inv)| it.service_variant_id == variant.id }

      if matching_pairs.any?
        matching_pairs.each do |it, inv|
          result << Item.new(
            service: variant.service,
            variant: variant,
            name: it.name,
            unit: it.unit,
            unit_price: it.unit_price,
            quantity: it.quantity.to_s.sub(/\.0$/, ""),
            amount: it.amount,
            status: :billed,
            invoice: inv
          )
        end
      else
        result << Item.new(
          service: variant.service,
          variant: variant,
          name: variant.service.name,
          unit: variant.human_unit,
          unit_price: variant.fee,
          quantity: "0",
          amount: 0,
          status: :waived,
          invoice: nil
        )
      end
    end

    extra_pairs = all_invoice_fixed_items.reject do |(it, _inv)|
      fixed_room_services.any? { |rs| rs.service_variant_id == it.service_variant_id }
    end

    extra_pairs.each do |it, inv|
      result << Item.new(
        service: it.service_variant&.service,
        variant: it.service_variant,
        name: it.name,
        unit: it.unit,
        unit_price: it.unit_price,
        quantity: it.quantity.to_s.sub(/\.0$/, ""),
        amount: it.amount,
        status: :billed,
        invoice: inv
      )
    end

    result
  end

  def build_draft_items
    fixed_room_services.map do |rs|
      variant = rs.service_variant
      qty = calculate_draft_quantity(variant)
      amount = (qty * variant.fee).round

      Item.new(
        service: variant.service,
        variant: variant,
        name: variant.service.name,
        unit: variant.human_unit,
        unit_price: variant.fee,
        quantity: qty.to_s.sub(/\.0$/, ""),
        amount: amount,
        status: :draft
      )
    end
  end

  def calculate_draft_quantity(variant)
    case variant.unit.to_sym
    when :per_room, :per_month
      if tenant.present? && house.mode != "bed" && room.invoices.where(invoice_type: "individual").exists?
        active_count = [ room.tenants_count, 1 ].max
        (1.0 / active_count).round(2)
      else
        1.0
      end
    when :per_person
      if tenant.present?
        1.0
      else
        room.tenants_count.to_f
      end
    when :per_item
      tenant_vehicle_count.to_f
    else
      1.0
    end
  end

  def tenant_vehicle_count
    if tenant.present?
      house.vehicles.where(tenant_id: tenant.id).count
    else
      @tenant_vehicle_count ||= house.vehicles.where(tenant_id: room.tenants.pluck(:id)).count
    end
  end

  def paginate_items
    @paginated_items = Kaminari.paginate_array(items).page(page).per(per_page)
  end
end
