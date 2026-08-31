class ServiceUpdatedNotifier < ApplicationNotifier
  required_param :service_name
  required_param :message_text

  notification_methods do
    def title
      t("noti.titles.service_updated", default: "Thông tin dịch vụ được cập nhật")
    end

    def message
      params[:message_text]
    end

    def url
      tenant_services_path
    end
  end
end
