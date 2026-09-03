class InvoicePaidNotifier < ApplicationNotifier
  required_param :invoice
  required_param :paid_by_role

  notification_methods do
    def title
      if recipient.landlord?
        if params[:paid_by_role] == "landlord"
          t("noti.titles.invoice_paid_landlord_self", code: params[:code])
        else
          t("noti.titles.invoice_paid_tenant_submit", code: params[:code])
        end
      else
        if params[:paid_by_role] == "landlord"
          t("noti.titles.invoice_paid_landlord_confirmed", code: params[:code])
        elsif recipient.id == params[:paid_by_id]
          t("noti.titles.invoice_paid_tenant_self", code: params[:code])
        else
          t("noti.titles.invoice_paid_roommate_submit", code: params[:code])
        end
      end
    end

    def message
      if recipient.landlord?
        if params[:paid_by_role] == "landlord"
          t("noti.messages.invoice_paid_landlord_self",
            code: params[:code],
            room_name: params[:room_name],
            amount: params[:amount],
            method: params[:method_label])
        else
          t("noti.messages.invoice_paid_tenant_submit",
            code: params[:code],
            actor_name: params[:actor_name],
            room_name: params[:room_name],
            amount: params[:amount],
            method: params[:method_label])
        end
      else
        if params[:paid_by_role] == "landlord"
          t("noti.messages.invoice_paid_landlord_confirmed",
            code: params[:code],
            room_name: params[:room_name],
            amount: params[:amount],
            method: params[:method_label])
        elsif recipient.id == params[:paid_by_id]
          t("noti.messages.invoice_paid_tenant_self",
            code: params[:code],
            room_name: params[:room_name],
            amount: params[:amount],
            method: params[:method_label])
        else
          t("noti.messages.invoice_paid_roommate_submit",
            code: params[:code],
            actor_name: params[:actor_name],
            room_name: params[:room_name],
            amount: params[:amount],
            method: params[:method_label])
        end
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
