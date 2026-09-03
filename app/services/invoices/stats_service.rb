# frozen_string_literal: true

module Invoices
  class StatsService
    def self.call(...)
      new(...).call
    end

    def initialize(invoices:)
      @invoices = invoices
    end

    def call
      valid_invoices = invoices.where.not(status: :cancelled)

      total_count = valid_invoices.count
      total_amount = valid_invoices.sum(:total_amount)
      paid_scope = valid_invoices.where(status: :paid)
      paid_amount = paid_scope.sum(:total_amount)
      paid_count = paid_scope.count
      pending_scope = valid_invoices.where(status: %i[pending overdue])
      pending_amount = pending_scope.sum(:total_amount)
      pending_count = valid_invoices.where(status: :pending).count

      overdue_scope = valid_invoices.where(status: :overdue).or(valid_invoices.where(status: :pending).where("due_date < ?", Date.current))
      overdue_count = overdue_scope.count
      overdue_amount = overdue_scope.sum(:total_amount)

      upcoming_unpaid = valid_invoices.where(status: :pending).where("due_date >= ?", Date.current).order(due_date: :asc)
      nearest_due_date = upcoming_unpaid.first&.due_date
      nearly_due_count = valid_invoices.where(status: :pending, due_date: Date.current..(Date.current + 3.days)).count

      collection_rate = total_amount.positive? ? ((paid_amount.to_f / total_amount) * 100).round(1) : 0
      pending_rate = total_amount.positive? ? [ 100 - collection_rate, 0 ].max.round(1) : 0

      {
        total_count: total_count,
        total_amount: total_amount,
        paid_amount: paid_amount,
        paid_count: paid_count,
        pending_amount: pending_amount,
        pending_count: pending_count,
        overdue_count: overdue_count,
        overdue_amount: overdue_amount,
        nearest_due_date: nearest_due_date,
        nearly_due_count: nearly_due_count,
        collection_rate: collection_rate,
        pending_rate: pending_rate
      }
    end

    private

    attr_reader :invoices
  end
end
