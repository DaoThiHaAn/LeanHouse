class RepairRequestCreatedNotifier < ApplicationNotifier
  required_param :request

  notification_methods do
    def title
      if recipient.landlord?
        t("noti.titles.repair_request_created_landlord", default: "Yêu cầu sửa chữa mới")
      else
        t("noti.titles.repair_request_created_tenant", default: "Đã gửi yêu cầu sửa chữa")
      end
    end

    def message
      if recipient.landlord?
        t("noti.messages.repair_request_created_landlord",
          tenant_name: params[:tenant_name],
          house_name: params[:house_name],
          location: params[:location],
          title: params[:title],
          default: "Khách thuê #{params[:tenant_name]} tại #{params[:house_name]} (#{params[:location]}) đã gửi yêu cầu sửa chữa: \"#{params[:title]}\".")
      else
        t("noti.messages.repair_request_created_tenant",
          house_name: params[:house_name],
          title: params[:title],
          default: "Yêu cầu sửa chữa \"#{params[:title]}\" tại #{params[:house_name]} đã được gửi thành công đến Chủ nhà.")
      end
    end

    def url
      if recipient.landlord?
        landlord_requests_path
      else
        tenant_requests_path
      end
    end
  end
end
