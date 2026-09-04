# frozen_string_literal: true

class LandlordServiceUsageLogsFilter
  def self.call(...)
    new(...).call
  end

  def initialize(house:, room: nil, params: {})
    @house = house
    @room = room
    @params = params
  end

  DEFAULT_PER_PAGE = 15

  def call
    scope = base_scope
    scope = apply_room(scope)
    scope = apply_floor(scope)
    scope = apply_service(scope)
    scope = apply_service_variant(scope)
    scope = apply_date_filter(scope)
    scope = apply_status(scope)

    scope = scope
      .preload({ room: :floor }, :service, :service_variant, :submitted_by, :confirmed_by, reading_photo_attachment: :blob)
      .order("service_usage_logs.billing_month DESC, service_usage_logs.created_at DESC")

    if params[:paginate] == false || params[:paginate] == "false"
      scope
    else
      scope.page(params[:page]).per(params[:per_page].presence || DEFAULT_PER_PAGE)
    end
  end

  private

  attr_reader :house, :room, :params

  def base_scope
    house.service_usage_logs
  end

  def apply_room(scope)
    target_room_id = room&.id || params[:room_id].presence
    return scope if target_room_id.blank?

    scope.where(room_id: target_room_id)
  end

  def apply_floor(scope)
    return scope if room.present? || params[:room_id].present?
    return scope if params[:floor_id].blank?

    scope.where(room_id: house.rooms.where(floor_id: params[:floor_id]).select(:id))
  end

  def apply_service(scope)
    return scope if params[:service_id].blank?

    scope.where(service_id: params[:service_id])
  end

  def apply_service_variant(scope)
    return scope if params[:service_variant_id].blank?

    scope.where(service_variant_id: params[:service_variant_id])
  end

  def apply_date_filter(scope)
    if params[:month].present? && params[:month].to_s.match?(/\A\d{4}-\d{2}\z/)
      month_date = Date.parse("#{params[:month]}-01").beginning_of_month
      scope.where(billing_month: month_date)
    elsif params[:year].present? && params[:month_num].present?
      month_date = Date.new(params[:year].to_i, params[:month_num].to_i, 1)
      scope.where(billing_month: month_date)
    elsif params[:year].present?
      year_val = params[:year].to_i
      scope.where(billing_month: Date.new(year_val, 1, 1)..Date.new(year_val, 12, 31))
    else
      scope
    end
  rescue ArgumentError
    scope
  end

  def apply_status(scope)
    case params[:status]
    when "confirmed"
      scope.confirmed
    when "unconfirmed"
      scope.unconfirmed
    when "billed"
      scope.where.not(invoice_id: nil)
    else
      scope
    end
  end
end
