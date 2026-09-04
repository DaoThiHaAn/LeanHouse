# frozen_string_literal: true

class TenantServicesFilter
  DEFAULT_PER_PAGE = 10

  def self.call(...)
    new(...).call
  end

  def initialize(room:, params: {})
    @room = room
    @params = params || {}
    @query = @params[:query]&.strip
    @page = @params[:page]
  end

  def call
    scope = base_scope
    scope = apply_search(scope)

    scope = scope
      .includes(service_variant: :service)
      .order("services.name ASC, service_variants.created_at ASC, room_services.id ASC")

    if params[:paginate] == false || params[:paginate] == "false"
      scope
    else
      scope.page(page).per(per_page)
    end
  end

  private

  attr_reader :room, :params, :query, :page

  def base_scope
    return RoomService.none unless room

    room.room_services.joins(service_variant: :service)
  end

  def apply_search(scope)
    return scope if query.blank?

    scope.where("services.name ILIKE :q", q: "%#{ActiveRecord::Base.sanitize_sql_like(query)}%")
  end

  def per_page
    params[:per_page].presence || DEFAULT_PER_PAGE
  end
end
