# frozen_string_literal: true

class RoomFixedServicesSummary
  DEFAULT_PER_PAGE = 10

  Item = Data.define(:service, :variant, :name, :unit, :unit_price, :quantity, :amount, :status) do
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

  attr_reader :room, :house, :billing_month, :page, :per_page,
              :items, :paginated_items, :active_invoice, :cancelled_invoices

  def self.call(...)
    new(...).call
  end

  def initialize(room:, billing_month: nil, page: nil, per_page: nil)
    @room = room
    @house = room.house
    @billing_month = (billing_month || Date.current).beginning_of_month
    @page = page.presence || 1
    @per_page = per_page.presence || DEFAULT_PER_PAGE
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
    active_invoice.present?
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
    @active_invoice = room.invoices
                          .kept
                          .where(status: %w[pending paid overdue])
                          .for_month(billing_month)
                          .includes(invoice_items: { service_variant: :service })
                          .first

    @cancelled_invoices = room.invoices
                              .where(status: :cancelled)
                              .for_month(billing_month)
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
    @items = if active_invoice.present?
               build_billed_items
             else
               build_draft_items
             end
  end

  def build_billed_items
    invoice_fixed_items = active_invoice.invoice_items.select(&:fixed_service?)
    result = []

    fixed_room_services.each do |rs|
      variant = rs.service_variant
      inv_item = invoice_fixed_items.find { |it| it.service_variant_id == variant.id }

      if inv_item.present?
        result << Item.new(
          service: variant.service,
          variant: variant,
          name: inv_item.name,
          unit: inv_item.unit,
          unit_price: inv_item.unit_price,
          quantity: inv_item.quantity.to_s.sub(/\.0$/, ""),
          amount: inv_item.amount,
          status: :billed
        )
      else
        result << Item.new(
          service: variant.service,
          variant: variant,
          name: variant.service.name,
          unit: variant.human_unit,
          unit_price: variant.fee,
          quantity: "0",
          amount: 0,
          status: :waived
        )
      end
    end

    extra_items = invoice_fixed_items.reject do |it|
      fixed_room_services.any? { |rs| rs.service_variant_id == it.service_variant_id }
    end

    extra_items.each do |it|
      result << Item.new(
        service: it.service_variant&.service,
        variant: it.service_variant,
        name: it.name,
        unit: it.unit,
        unit_price: it.unit_price,
        quantity: it.quantity.to_s.sub(/\.0$/, ""),
        amount: it.amount,
        status: :billed
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
      1.0
    when :per_person
      room.tenants_count.to_f
    when :per_item
      tenant_vehicle_count.to_f
    else
      1.0
    end
  end

  def tenant_vehicle_count
    @tenant_vehicle_count ||= house.vehicles.where(tenant_id: room.tenants.pluck(:id)).count
  end

  def paginate_items
    @paginated_items = Kaminari.paginate_array(items).page(page).per(per_page)
  end
end
