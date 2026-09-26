module LandlordDashboard
  class RevenueStatsCalculator
    def self.call(...)
      new(...).call
    end

    def initialize(landlord:, target_houses:, house_id: nil, target_date: Date.current)
      @landlord = landlord
      @target_houses = target_houses
      @house_id = house_id
      @target_date = target_date
    end

    def call
      house_ids = target_houses.select(:id)
      return empty_res if house_ids.empty?

      invoices_scope = Invoice.where(house_id: house_ids)
                              .for_month(target_date.beginning_of_month)
                              .where.not(status: :cancelled)

      rev_stats = invoices_scope.select(
        ActiveRecord::Base.sanitize_sql_array([
          "COALESCE(SUM(total_amount), 0) AS total_revenue,
           COALESCE(SUM(total_amount) FILTER (WHERE status = 'paid'), 0) AS paid_revenue,
           COALESCE(SUM(total_amount) FILTER (WHERE status != 'paid'), 0) AS pending_revenue"
        ])
      ).take

      total_rev = rev_stats.total_revenue.to_i
      paid_rev = rev_stats.paid_revenue.to_i
      pending_rev = rev_stats.pending_revenue.to_i

      # Items breakdown (Rent vs Services)
      items_scope = InvoiceItem.joins(:invoice)
                               .where(invoices: { id: invoices_scope.select(:id) })

      item_stats = items_scope.select(
        ActiveRecord::Base.sanitize_sql_array([
          "COALESCE(SUM(invoice_items.amount) FILTER (WHERE invoice_items.item_type = 'rent'), 0) AS rent_total,
           COALESCE(SUM(invoice_items.amount) FILTER (WHERE invoice_items.item_type IN ('metered_service', 'fixed_service')), 0) AS services_total"
        ])
      ).take

      rent_total = item_stats.rent_total.to_i
      services_total = item_stats.services_total.to_i

      items_sum = rent_total + services_total
      rent_pct = items_sum.positive? ? ((rent_total.to_f / items_sum) * 100).round(1) : 0.0
      services_pct = items_sum.positive? ? [ 100.0 - rent_pct, 0.0 ].max.round(1) : 0.0

      all_active_houses = landlord.houses.active.sorted
      all_invoices_scope = Invoice.where(house_id: all_active_houses.select(:id))
                                  .for_month(target_date.beginning_of_month)
                                  .where.not(status: :cancelled)

      total_portfolio_paid = all_invoices_scope.where(status: :paid).sum(:total_amount).to_i

      portfolio_share = if house_id && total_portfolio_paid.positive?
        ((paid_rev.to_f / total_portfolio_paid) * 100).round(1)
      else
        100.0
      end

      house_portions = []
      if house_id.nil? && all_active_houses.any?
        house_paid_map = all_invoices_scope.where(status: :paid)
                                           .group(:house_id)
                                           .sum(:total_amount)

        all_active_houses.each_with_index do |house, idx|
          h_paid = house_paid_map[house.id].to_i
          h_pct = total_portfolio_paid.positive? ? ((h_paid.to_f / total_portfolio_paid) * 100).round(1) : 0.0
          house_portions << {
            id: house.id,
            name: house.name,
            paid_revenue: h_paid,
            percentage: h_pct,
            color_index: idx % 6
          }
        end
      end

      # Fixed latest 6-month window relative to Date.current
      latest_curr_month = Date.current.beginning_of_month
      latest_start_period = latest_curr_month - 5.months
      latest_end_period = Date.current.end_of_month

      trend_paid_map = Invoice.where(house_id: house_ids)
                              .where(billing_month: latest_start_period..latest_end_period)
                              .where(status: :paid)
                              .where.not(status: :cancelled)
                              .group(:billing_month)
                              .sum(:total_amount)
                              .transform_keys { |k| k.is_a?(String) ? Date.parse(k).beginning_of_month : k.beginning_of_month }

      # MoM for target_date
      prev_month_date = target_date.prev_month.beginning_of_month
      prev_month_paid = if trend_paid_map.key?(prev_month_date)
        trend_paid_map[prev_month_date].to_i
      else
        Invoice.where(house_id: house_ids)
               .for_month(prev_month_date)
               .where(status: :paid)
               .where.not(status: :cancelled)
               .sum(:total_amount).to_i
      end

      has_prev_data = prev_month_paid.positive? || paid_rev.positive?
      mom_diff = paid_rev - prev_month_paid

      mom_pct = if prev_month_paid.positive?
        (((paid_rev - prev_month_paid).to_f / prev_month_paid) * 100).round(1)
      elsif prev_month_paid.zero? && paid_rev.positive?
        100.0
      else
        0.0
      end

      monthly_trend = (0..5).reverse_each.map do |i|
        m = (latest_curr_month - i.months).beginning_of_month
        amount = trend_paid_map[m].to_i
        {
          date: m,
          month_label: m.strftime("%m/%y"),
          month_full: m.strftime("%m/%Y"),
          month_param: m.strftime("%Y-%m"),
          paid_revenue: amount,
          is_target: (m == target_date.beginning_of_month),
          is_current: (m == Date.current.beginning_of_month)
        }
      end

      max_trend_rev = monthly_trend.map { |t| t[:paid_revenue] }.max.to_i
      min_trend_rev = monthly_trend.map { |t| t[:paid_revenue] }.min.to_i
      total_6m = monthly_trend.sum { |t| t[:paid_revenue] }
      avg_monthly = (total_6m.to_f / 6).round

      max_item = monthly_trend.max_by { |t| t[:paid_revenue] }
      min_item = monthly_trend.min_by { |t| t[:paid_revenue] }

      monthly_trend.each do |t|
        t[:height_pct] = if t[:paid_revenue].positive? && max_trend_rev.positive?
          [ ((t[:paid_revenue].to_f / max_trend_rev) * 100).round, 3 ].max
        else
          0
        end
        t[:is_max] = (max_trend_rev.positive? && t[:paid_revenue] == max_trend_rev)
        t[:is_min] = (t[:paid_revenue] == min_trend_rev)
      end

      macro_comparison = {
        avg_monthly_revenue: avg_monthly,
        total_6m_revenue: total_6m,
        max_month: max_item,
        min_month: min_item
      }

      # Y-Axis Scale Levels (4 levels: 100%, 75%, 50%, 25%, 0%)
      scale_ceiling = max_trend_rev.positive? ? max_trend_rev : 10_000_000
      y_axis_levels = [
        { percentage: 100, amount: scale_ceiling },
        { percentage: 75, amount: (scale_ceiling * 0.75).round },
        { percentage: 50, amount: (scale_ceiling * 0.50).round },
        { percentage: 25, amount: (scale_ceiling * 0.25).round },
        { percentage: 0, amount: 0 }
      ]

      {
        total_revenue: total_rev,
        paid_revenue: paid_rev,
        pending_revenue: pending_rev,
        rent_revenue: rent_total,
        service_revenue: services_total,
        rent_percentage: rent_pct,
        service_percentage: services_pct,
        portfolio_share: portfolio_share,
        house_portions: house_portions,
        prev_month_paid: prev_month_paid,
        mom_diff: mom_diff,
        mom_percentage: mom_pct,
        has_prev_data: has_prev_data,
        monthly_trend: monthly_trend,
        macro_comparison: macro_comparison,
        y_axis_levels: y_axis_levels
      }
    end

    private

    attr_reader :landlord, :target_houses, :house_id, :target_date

    def empty_res
      {
        total_revenue: 0,
        paid_revenue: 0,
        pending_revenue: 0,
        rent_revenue: 0,
        service_revenue: 0,
        rent_percentage: 0.0,
        service_percentage: 0.0,
        portfolio_share: 0.0,
        house_portions: [],
        prev_month_paid: 0,
        mom_diff: 0,
        mom_percentage: 0.0,
        has_prev_data: false,
        monthly_trend: [],
        macro_comparison: {
          avg_monthly_revenue: 0,
          total_6m_revenue: 0,
          max_month: nil,
          min_month: nil
        },
        y_axis_levels: []
      }
    end
  end
end
