module LandlordDashboard
  class InvoiceStatsCalculator
    def self.call(...)
      new(...).call
    end

    def initialize(target_houses, target_date = Date.current)
      @target_houses = target_houses
      @target_date = target_date
    end

    def call
      house_ids = target_houses.select(:id)
      empty_res = { total: 0, pending: 0, paid: 0, overdue: 0, total_amount: 0, paid_amount: 0, pending_amount: 0, collection_rate: 0.0 }
      return empty_res if house_ids.empty?

      invoices_scope = Invoice.where(house_id: house_ids)
                              .for_month(target_date.beginning_of_month)
                              .where.not(status: :cancelled)

      today = Date.current

      stats = invoices_scope.select(
        ActiveRecord::Base.sanitize_sql_array([
          "COUNT(*) AS total_count,
           COUNT(*) FILTER (WHERE status = 'paid') AS paid_count,
           COUNT(*) FILTER (WHERE status = 'pending') AS pending_count,
           COUNT(*) FILTER (WHERE status = 'overdue' OR (status = 'pending' AND due_date < :today)) AS overdue_count,
           COALESCE(SUM(total_amount), 0) AS total_amount,
           COALESCE(SUM(total_amount) FILTER (WHERE status = 'paid'), 0) AS paid_amount,
           COALESCE(SUM(total_amount) FILTER (WHERE status = 'pending' OR status = 'overdue'), 0) AS pending_amount",
          { today: today }
        ])
      ).take

      total_count = stats&.total_count.to_i
      paid_count = stats&.paid_count.to_i
      pending_count = stats&.pending_count.to_i
      overdue_count = stats&.overdue_count.to_i
      total_amount = stats&.total_amount.to_i
      paid_amount = stats&.paid_amount.to_i
      pending_amount = stats&.pending_amount.to_i

      collection_rate = total_amount.positive? ? ((paid_amount.to_f / total_amount) * 100).round(1) : 0.0

      {
        total: total_count,
        paid: paid_count,
        pending: pending_count,
        overdue: overdue_count,
        total_amount: total_amount,
        paid_amount: paid_amount,
        pending_amount: pending_amount,
        collection_rate: collection_rate
      }
    end

    private

    attr_reader :target_houses, :target_date
  end
end
