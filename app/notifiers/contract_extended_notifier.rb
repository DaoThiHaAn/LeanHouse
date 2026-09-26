class ContractExtendedNotifier < ApplicationNotifier
  required_param :contract

  notification_methods do
    def title
      t("noti.titles.contract_extended", default: "Hợp đồng được gia hạn")
    end

    def message
      formatted_date = params[:due_date].respond_to?(:strftime) ? params[:due_date].strftime("%d/%m/%Y") : params[:due_date].to_s
      t("noti.messages.contract_extended",
        contract_name: params[:contract_name],
        date: formatted_date,
        default: "#{params[:contract_name]} được gia hạn đến #{formatted_date}.")
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
