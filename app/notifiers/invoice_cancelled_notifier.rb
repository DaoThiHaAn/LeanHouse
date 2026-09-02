class InvoiceCancelledNotifier < ApplicationNotifier
  required_param :invoice

  notification_methods do
    def title
      t("noti.titles.invoice_cancelled", month: params[:month])
    end

    def message
      t("noti.messages.invoice_cancelled_tenant",
        code: params[:code],
        room_name: params[:room_name],
        month: params[:month]
      )
    end

    def url
      tenant_invoices_path(month: params[:raw_month])
    end
  end
end
