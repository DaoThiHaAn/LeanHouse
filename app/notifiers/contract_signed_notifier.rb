class ContractSignedNotifier < ApplicationNotifier
  required_param :contract

  notification_methods do
    def title
      if recipient.landlord?
        t("noti.titles.contract_created_landlord")
      else
        t("noti.titles.contract_signed")
      end
    end

    def message
      if recipient.landlord?
        t("noti.messages.contract_signed_landlord",
          contract_name: params[:contract_name],
          tenant_name: params[:tenant_name])
      else
        t("noti.messages.contract_signed",
          contract_name: params[:contract_name])
      end
    end

    def url
      if recipient.landlord?
        landlord_house_contracts_path(params[:house_id])
      else
        tenant_contract_path
      end
    end
  end
end
