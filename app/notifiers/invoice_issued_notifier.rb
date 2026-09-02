class InvoiceIssuedNotifier < ApplicationNotifier
  required_param :invoice

  notification_methods do
    def title
      t("noti.titles.invoice_issued", month: params[:month])
    end

    def message
      t("noti.messages.invoice_issued_tenant",
        code: params[:code],
        room_name: params[:room_name],
        month: params[:month],
        amount: params[:amount],
        due_date: params[:due_date]
      )
    end

    def url
      tenant_invoices_path(status: :pending, month: params[:raw_month])
    end
  end
end
