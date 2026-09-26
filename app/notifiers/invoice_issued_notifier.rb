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
      tenant_invoice_path(params[:invoice] || params[:invoice_id])
    end
  end
end
