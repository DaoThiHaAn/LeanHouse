module LandlordDashboard
  class ContractStatsCalculator
    def self.call(...)
      new(...).call
    end

    def initialize(target_houses)
      @target_houses = target_houses
    end

    def call
      house_ids = target_houses.select(:id)
      return { overdue: 0, nearly_due: 0, total: 0 } if house_ids.empty?

      scope = Contract.where(house_id: house_ids, end_date: nil)

      today = Date.current
      nearly_due_end = today + Contract::NEARLY_DUE_DAYS.days

      result = scope.select(
        ActiveRecord::Base.sanitize_sql_array([
          "COUNT(*) FILTER (WHERE contracts.due_date < :today) AS overdue_count,
           COUNT(*) FILTER (WHERE contracts.due_date BETWEEN :today AND :nearly_due_end) AS nearly_due_count",
          { today: today, nearly_due_end: nearly_due_end }
        ])
      ).take

      overdue = result&.overdue_count.to_i
      nearly_due = result&.nearly_due_count.to_i

      {
        overdue: overdue,
        nearly_due: nearly_due,
        total: overdue + nearly_due
      }
    end

    private

    attr_reader :target_houses
  end
end
