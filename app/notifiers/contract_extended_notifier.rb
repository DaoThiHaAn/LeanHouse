class ContractExtendedNotifier < ApplicationNotifier
  required_param :contract

  notification_methods do
    def title
      t("noti.titles.contract_extended", default: "Hợp đồng được gia hạn")
    end

    def message
      t("noti.messages.contract_extended",
        contract_name: params[:contract_name],
        date: params[:due_date]&.strftime("%d/%m/%Y"),
        default: "#{params[:contract_name]} được gia hạn đến #{params[:due_date]&.strftime('%d/%m/%Y')}.")
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
