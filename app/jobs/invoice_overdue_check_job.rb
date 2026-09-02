class InvoiceOverdueCheckJob < ApplicationJob
  queue_as :default

  def perform
    Invoice.kept
           .where(status: [ :pending, :overdue ])
           .where("due_date < ?", Date.current)
           .includes(:house, :room, :tenant, :created_by)
           .find_each do |invoice|
      # Mark pending invoices as overdue
      invoice.update_columns(status: :overdue) if invoice.pending?

      days_overdue = (Date.current - invoice.due_date).to_i

      # Smart Cadence: Notify on Day 1 (just became overdue), Day 3, and Day 7
      # This prevents daily spamming while ensuring critical overdue reminders
      next unless [ 1, 3, 7 ].include?(days_overdue)

      formatted_amount = "#{invoice.total_amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}đ"
      landlord_user = invoice.house&.landlord&.user || invoice.created_by
      tenant_users = invoice.target_users

      # Deliver to landlord
      if landlord_user.present?
        InvoiceOverdueNotifier.with(
          invoice: invoice,
          code: invoice.code,
          room_name: invoice.room.title_name,
          amount: formatted_amount,
          due_date: invoice.due_date.strftime("%d/%m/%Y"),
          raw_month: invoice.billing_month.strftime("%Y-%m"),
          house_id: invoice.house_id
        ).deliver_later(landlord_user)
      end

      # Deliver to tenants
      if tenant_users.present? && tenant_users.any?
        InvoiceOverdueNotifier.with(
          invoice: invoice,
          code: invoice.code,
          room_name: invoice.room.title_name,
          amount: formatted_amount,
          due_date: invoice.due_date.strftime("%d/%m/%Y"),
          raw_month: invoice.billing_month.strftime("%Y-%m"),
          house_id: invoice.house_id
        ).deliver_later(tenant_users)
      end
    end
  end
end
