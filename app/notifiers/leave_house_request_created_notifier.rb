class LeaveHouseRequestCreatedNotifier < ApplicationNotifier
  required_param :request

  notification_methods do
    def title
      if recipient.landlord?
        t("noti.titles.leave_house_request_created_landlord", default: "Yêu cầu rời nhà mới")
      else
        t("noti.titles.leave_house_request_created_tenant", default: "Đã gửi yêu cầu rời nhà")
      end
    end

    def message
      if recipient.landlord?
        t("noti.messages.leave_house_request_created_landlord",
          tenant_name: params[:tenant_name],
          house_name: params[:house_name],
          location: params[:location],
          default: "Khách thuê #{params[:tenant_name]} tại #{params[:house_name]} (#{params[:location]}) đã gửi yêu cầu rời nhà.")
      else
        t("noti.messages.leave_house_request_created_tenant",
          house_name: params[:house_name],
          default: "Yêu cầu rời nhà tại #{params[:house_name]} đã được gửi thành công đến Chủ nhà.")
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
