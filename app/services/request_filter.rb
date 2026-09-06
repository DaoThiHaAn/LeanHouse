class RequestFilter
  REQUESTS_PER_PAGE = 15

  def self.call(...)
    new(...).call
  end

  def initialize(scope: nil, landlord: nil, tenant: nil, current_house_id: nil, params: {}, per_page: nil)
    @custom_scope = scope
    @landlord = landlord
    @tenant = tenant
    @current_house_id = current_house_id
    @params = params
    @query = (params[:q] || params[:query])&.strip
    @house_id = params[:house_id]
    @from_date = params[:from_date].presence || params[:start_date].presence
    @to_date = params[:to_date].presence || params[:end_date].presence
    @sent_month = params[:sent_month]
    @month = params[:month]
    @year = params[:year]
    @status = params[:status]
    @request_type = params[:request_type]
    @page = params[:page]
    @per_page = per_page || REQUESTS_PER_PAGE
  end

  def call
    scope = base_scope
    scope = apply_search(scope)
    scope = apply_house_filter(scope)
    scope = apply_sent_time_filter(scope)
    scope = apply_status_filter(scope)
    scope = apply_request_type_filter(scope)

    scope
      .includes(:house, :requestable, :resolved_by, tenant: :user)
      .order(created_at: :desc, id: :desc)
      .page(page)
      .per(per_page)
  end

  private

  attr_reader :custom_scope, :landlord, :tenant, :current_house_id, :params,
              :query, :house_id, :from_date, :to_date, :sent_month, :month, :year,
              :status, :request_type, :page, :per_page

  def base_scope
    return custom_scope if custom_scope.present?
    return landlord.requests if landlord.present?
    return tenant.requests if tenant.present?

    Request.all
  end

  def apply_search(scope)
    return scope if query.blank?

    q = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    if query.match?(/\A\d+\z/)
      scope.left_joins(:house, tenant: :user).where(
        "requests.id = :id OR unaccent(houses.name) ILIKE unaccent(:q) OR unaccent(users.fullname) ILIKE unaccent(:q) OR users.tel ILIKE :q",
        id: query.to_i, q: q
      )
    else
      scope.left_joins(:house, tenant: :user).where(
        "unaccent(houses.name) ILIKE unaccent(:q) OR unaccent(users.fullname) ILIKE unaccent(:q) OR users.tel ILIKE :q",
        q: q
      )
    end
  end

  def apply_house_filter(scope)
    if params.key?(:house_id)
      return scope if house_id.blank? || house_id == "all"
      scope.where(house_id: house_id)
    elsif current_house_id.present?
      scope.where(house_id: current_house_id)
    else
      scope
    end
  end

  def apply_sent_time_filter(scope)
    if from_date.present? || to_date.present?
      begin
        start_time = from_date.present? ? Date.parse(from_date.to_s).beginning_of_day : nil
        end_time = to_date.present? ? Date.parse(to_date.to_s).end_of_day : nil

        is_default_today = start_time.nil? && end_time && end_time.to_date >= Date.current
        has_period_filter = month.present? || year.present? || sent_month.present?

        unless is_default_today && has_period_filter
          if start_time && end_time
            start_time, end_time = end_time.beginning_of_day, start_time.end_of_day if start_time > end_time
            return scope.where(created_at: start_time..end_time)
          elsif start_time
            return scope.where("requests.created_at >= ?", start_time)
          elsif end_time && end_time.to_date < Date.current
            return scope.where("requests.created_at <= ?", end_time)
          end
        end
      rescue ArgumentError, TypeError
      end
    end

    if month.present? && year.present?
      begin
        date = Date.new(year.to_i, month.to_i, 1)
        start_time = date.beginning_of_month.beginning_of_day
        end_time = date.end_of_month.end_of_day
        return scope.where(created_at: start_time..end_time)
      rescue ArgumentError, TypeError
      end
    elsif year.present?
      begin
        start_time = Date.new(year.to_i, 1, 1).beginning_of_year.beginning_of_day
        end_time = Date.new(year.to_i, 12, 31).end_of_year.end_of_day
        return scope.where(created_at: start_time..end_time)
      rescue ArgumentError, TypeError
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
