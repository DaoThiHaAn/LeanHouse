class ContractDueTodayNotifier < ApplicationNotifier
  required_param :contract

  notification_methods do
    def title
      t("noti.titles.contract_due_today")
    end

    def message
      if recipient.landlord?
        t("noti.messages.contract_due_today_landlord",
          contract_name: params[:contract_name],
          tenant_name: params[:tenant_name],
          due_date: params[:due_date])
      else
        t("noti.messages.contract_due_today_tenant",
          contract_name: params[:contract_name],
          due_date: params[:due_date])
      end
    end

    def url
      if recipient.landlord?
        landlord_house_contract_path(params[:house_id], params[:contract_id])
      else
        tenant_contract_path
      end
    end
  end
end
