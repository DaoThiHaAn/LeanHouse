class InvoiceCreationReminderNotifier < ApplicationNotifier
  required_param :house

  notification_methods do
    def title
      t("noti.titles.invoice_creation_reminder")
    end

    def message
      t("noti.messages.invoice_creation_reminder", house_name: params[:house_name])
    end

    def url
      month_str = params[:month].presence || Date.current.strftime("%Y-%m")
      landlord_house_invoices_path(params[:house_id], month: month_str)
    end
  end
end
