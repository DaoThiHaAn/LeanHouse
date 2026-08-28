class LandlordRequestFilter
  REQUESTS_PER_PAGE = 10

  def self.call(...)
    new(...).call
  end

  def initialize(landlord:, params:)
    @landlord = landlord
    @params = params
    @house_id = params[:house_id]
    @sent_month = params[:sent_month]
    @month = params[:month]
    @year = params[:year]
    @status = params[:status]
    @request_type = params[:request_type]
    @page = params[:page]
  end

  def call
    scope = base_scope
    scope = apply_house_filter(scope)
    scope = apply_sent_time_filter(scope)
    scope = apply_status_filter(scope)
    scope = apply_request_type_filter(scope)

    scope
      .includes(:house, :requestable, :resolved_by, tenant: :user)
      .order(created_at: :desc, id: :desc)
      .page(page)
      .per(REQUESTS_PER_PAGE)
  end

  private

  attr_reader :landlord, :params, :house_id,
              :sent_month, :month, :year, :status, :request_type, :page

  def base_scope
    landlord.requests
  end

  def apply_house_filter(scope)
    return scope if house_id.blank? || house_id == "all"

    scope.where(house_id: house_id)
  end

  def apply_sent_time_filter(scope)
    if month.present? && year.present?
      begin
        date = Date.new(year.to_i, month.to_i, 1)
        start_time = date.beginning_of_month.beginning_of_day
        end_time = date.end_of_month.end_of_day
        return scope.where(created_at: start_time..end_time)
      rescue ArgumentError, TypeError
        # Ignore invalid date
      end
    elsif year.present?
      begin
        start_time = Date.new(year.to_i, 1, 1).beginning_of_year.beginning_of_day
        end_time = Date.new(year.to_i, 12, 31).end_of_year.end_of_day
        return scope.where(created_at: start_time..end_time)
      rescue ArgumentError, TypeError
        # Ignore invalid year
      end
    elsif month.present?
      return scope.where("EXTRACT(MONTH FROM requests.created_at) = ?", month.to_i)
    elsif sent_month.present?
      begin
        date = Date.strptime(sent_month.to_s, "%Y-%m")
        start_time = date.beginning_of_month.beginning_of_day
        end_time = date.end_of_month.end_of_day
        return scope.where(created_at: start_time..end_time)
      rescue ArgumentError, TypeError
        # Ignore invalid format
      end
    end

    scope
  end

  def apply_status_filter(scope)
    return scope if status.blank? || status == "all"

    if Request.statuses.key?(status.to_s)
      scope.where(status: status)
    else
      scope
    end
  end

  def apply_request_type_filter(scope)
    return scope if request_type.blank? || request_type == "all"

    scope.where(requestable_type: request_type)
  end
end
