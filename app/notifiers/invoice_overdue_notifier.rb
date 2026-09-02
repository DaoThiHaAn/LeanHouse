class InvoiceOverdueNotifier < ApplicationNotifier
  required_param :invoice

  notification_methods do
    def title
      if recipient.landlord?
        t("noti.titles.invoice_overdue_landlord")
      else
        t("noti.titles.invoice_overdue")
      end
    end

    def message
      if recipient.landlord?
        t("noti.messages.invoice_overdue_landlord",
          code: params[:code],
          room_name: params[:room_name],
          amount: params[:amount],
          due_date: params[:due_date]
        )
      else
        t("noti.messages.invoice_overdue_tenant",
          code: params[:code],
          room_name: params[:room_name],
          amount: params[:amount],
          due_date: params[:due_date]
        )
      end
    end

    def url
      if recipient.landlord?
        landlord_house_invoices_path(params[:house_id], status: :overdue, month: params[:raw_month])
      else
        tenant_invoices_path(status: :overdue, month: params[:raw_month])
      end
    end
  end
end
