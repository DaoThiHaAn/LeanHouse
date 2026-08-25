class ContractOverdueClosedNotifier < ApplicationNotifier
  required_param :contract

  notification_methods do
    def title
      t("noti.titles.contract_overdue_closed")
    end

    def message
      if recipient.landlord?
        t("noti.messages.contract_overdue_closed_landlord",
          contract_name: params[:contract_name],
          tenant_name: params[:tenant_name])
      else
        t("noti.messages.contract_overdue_closed_tenant",
          contract_name: params[:contract_name])
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
