class ContractClosedNotifier < ApplicationNotifier
  required_param :contract

  notification_methods do
    def title
      if recipient.landlord?
        t("noti.titles.contract_closed_landlord", default: "Hợp đồng đã kết thúc")
      else
        t("noti.titles.contract_closed")
      end
    end

    def message
      if recipient.landlord?
        t("noti.messages.contract_closed_landlord",
          contract_name: params[:contract_name],
          tenant_name: params[:tenant_name],
          default: "Hợp đồng %{contract_name} với khách %{tenant_name} đã được kết thúc thành công.")
      else
        t("noti.messages.contract_closed_early",
          contract_name: params[:contract_name],
          default: "Hợp đồng %{contract_name} đã kết thúc trước thời hạn.")
      end
    end

    def url
      if recipient.landlord?
        landlord_house_contracts_path(params[:house_id])
      else
        tenant_old_contracts_path
      end
    end
  end
end
