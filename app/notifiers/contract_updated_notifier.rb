class ContractUpdatedNotifier < ApplicationNotifier
  required_param :contract

  notification_methods do
    def title
      if recipient.landlord?
        t("noti.titles.contract_updated_landlord")
      else
        t("noti.titles.contract_updated")
      end
    end

    def message
      if recipient.landlord?
        t("noti.messages.contract_updated_landlord",
          contract_name: params[:contract_name],
          tenant_name: params[:tenant_name])
      else
        t("noti.messages.contract_updated_tenant",
          contract_name: params[:contract_name])
      end
    end

    def url
      if recipient.landlord?
        landlord_house_contract_path(params[:house_id], params[:contract_id] || params[:contract]&.id)
      else
        tenant_contract_path
      end
    end
  end
end
