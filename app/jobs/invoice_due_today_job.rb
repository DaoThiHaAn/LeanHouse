class InvoiceDueTodayJob < ApplicationJob
  queue_as :default

  def perform
    Invoice.kept
           .pending
           .where(due_date: Date.current)
           .includes(:house, :room, :tenant, :created_by)
           .find_each do |invoice|
      formatted_amount = "#{invoice.total_amount.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}đ"
      landlord_user = invoice.house&.landlord&.user || invoice.created_by
      tenant_users = invoice.target_users

      # Deliver to landlord
      if landlord_user.present?
        InvoiceDueTodayNotifier.with(
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
        InvoiceDueTodayNotifier.with(
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
