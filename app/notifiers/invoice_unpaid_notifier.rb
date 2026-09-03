class InvoiceUnpaidNotifier < ApplicationNotifier
  required_param :invoice
  required_param :explanation

  notification_methods do
    def title
      if recipient.landlord?
        t("noti.titles.invoice_unpaid_landlord", code: params[:code])
      else
        t("noti.titles.invoice_unpaid_tenant", code: params[:code])
      end
    end

    def message
      if recipient.landlord?
        t("noti.messages.invoice_unpaid_landlord",
          code: params[:code],
          room_name: params[:room_name],
          explanation: params[:explanation])
      else
        t("noti.messages.invoice_unpaid_tenant",
          code: params[:code],
          room_name: params[:room_name],
          landlord_name: params[:actor_name],
          explanation: params[:explanation])
      end
    end

    def url
      if recipient.landlord?
        landlord_house_invoice_path(params[:house_id], params[:invoice_id])
      else
        tenant_invoice_path(params[:invoice_id])
      end
    end
  end
end
