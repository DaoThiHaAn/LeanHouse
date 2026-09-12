# frozen_string_literal: true

class HouseFixedServicesSummary
  DEFAULT_PER_PAGE = 15

  Item = Data.define(:room, :service, :variant, :name, :unit, :unit_price, :quantity, :amount, :status, :invoice) do
    def initialize(room:, service:, variant:, name:, unit:, unit_price:, quantity:, amount:, status:, invoice: nil)
      super(
        room: room,
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

  attr_reader :house, :billing_month, :params, :page, :per_page,
              :items, :paginated_items, :rooms

  def self.call(...)
    new(...).call
  end

  def initialize(house:, billing_month: nil, params: {})
    @house = house
    @billing_month = (billing_month || Date.current).beginning_of_month
    @params = params.is_a?(ActionController::Parameters) ? params.to_unsafe_h : (params || {})
    @page = @params[:page].presence || 1
    @per_page = @params[:per_page].presence || DEFAULT_PER_PAGE
    @items = []
  end

  def call
    load_rooms
    load_invoices
    load_vehicles
    build_items
    apply_filters
    paginate_items
    self
  end

  def total_amount
    @total_amount ||= items.sum(&:amount)
  end

  def total_rooms_count
    @total_rooms_count ||= items.map { |it| it.room.id }.uniq.size
  end

  def total_items_count
    items.size
  end

  def billed_count
    @billed_count ||= items.count(&:billed?)
  end

  def draft_count
    @draft_count ||= items.count(&:draft?)
  end

  def waived_count
    @waived_count ||= items.count(&:waived?)
  end

  def billing_month_str
    billing_month.strftime("%Y-%m")
  end

  private

  def load_rooms
    scope = house.rooms.active.sorted.includes(:floor, :tenants, room_services: { service_variant: :service })

    if params[:room_id].present?
      scope = scope.where(id: params[:room_id])
    elsif params[:floor_id].present?
      scope = scope.where(floor_id: params[:floor_id])
    end

    @rooms = scope.to_a
  end

  def load_invoices
    room_ids = rooms.map(&:id)
    return @invoices_by_room = {} if room_ids.empty?

    invoices = Invoice.where(room_id: room_ids)
                      .for_month(billing_month)
                      .kept
                      .where(status: %w[pending paid overdue])
                      .includes(invoice_items: { service_variant: :service })
                      .order(created_at: :desc)

    @invoices_by_room = invoices.group_by(&:room_id)
  end

  def load_vehicles
    tenant_ids = rooms.flat_map { |r| r.tenants.map(&:id) }
    return @vehicles_count_by_tenant = {} if tenant_ids.empty?

    @vehicles_count_by_tenant = house.vehicles.where(tenant_id: tenant_ids).group(:tenant_id).count
  end

  def build_items
    @items = []

    rooms.each do |room|
      room_invoices = @invoices_by_room[room.id] || []
      fixed_room_services = room.room_services.select do |rs|
        rs.service_variant.present? &&
          !rs.service_variant.is_real_time? &&
          rs.created_at <= billing_month.end_of_month
      end

      if room_invoices.present?
        build_billed_items_for(room, fixed_room_services, room_invoices)
      else
        build_draft_items_for(room, fixed_room_services)
      end
    end
  end

  def build_billed_items_for(room, fixed_room_services, room_invoices)
    all_invoice_fixed_items = room_invoices.flat_map do |inv|
      inv.invoice_items.select(&:fixed_service?).map { |it| [ it, inv ] }
    end

    fixed_room_services.each do |rs|
      variant = rs.service_variant
      matching_pairs = all_invoice_fixed_items.select { |(it, _inv)| it.service_variant_id == variant.id }

      if matching_pairs.any?
        matching_pairs.each do |it, inv|
          @items << Item.new(
            room: room,
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
        @items << Item.new(
          room: room,
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
      @items << Item.new(
        room: room,
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
  end

  def build_draft_items_for(room, fixed_room_services)
    fixed_room_services.each do |rs|
      variant = rs.service_variant
      qty = calculate_draft_quantity(room, variant)
      amount = (qty * variant.fee).round

      @items << Item.new(
        room: room,
        service: variant.service,
        variant: variant,
        name: variant.service.name,
        unit: variant.human_unit,
        unit_price: variant.fee,
        quantity: qty.to_s.sub(/\.0$/, ""),
        amount: amount,
        status: :draft,
        invoice: nil
      )
    end
  end

  def calculate_draft_quantity(room, variant)
    case variant.unit.to_sym
    when :per_room, :per_month
      1.0
    when :per_person
      room.tenants_count.to_f
    when :per_item
      room_vehicles_count(room).to_f
    else
      1.0
    end
  end

  def room_vehicles_count(room)
    room.tenants.sum { |t| @vehicles_count_by_tenant[t.id].to_i }
  end

  def apply_filters
    if params[:service_id].present?
      @items.select! { |it| it.service&.id.to_s == params[:service_id].to_s }
    end

    if params[:service_variant_id].present?
      @items.select! { |it| it.variant&.id.to_s == params[:service_variant_id].to_s }
    end

    if params[:status].present?
      @items.select! { |it| it.status.to_s == params[:status].to_s }
    end
  end

  def paginate_items
    @paginated_items = Kaminari.paginate_array(items).page(page).per(per_page)
  end
end
