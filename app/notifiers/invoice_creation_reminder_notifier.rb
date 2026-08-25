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
      landlord_house_invoices_path(params[:house_id])
    end
  end
end
