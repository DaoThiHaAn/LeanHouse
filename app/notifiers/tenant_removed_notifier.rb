class TenantRemovedNotifier < ApplicationNotifier
  required_param :tenant_stay

  notification_methods do
    def title
      if recipient.landlord?
        t("noti.titles.tenant_removed_landlord", default: "Đã xóa khách thuê khỏi nhà")
      else
        t("noti.titles.rem_from_house")
      end
    end

    def message
      if recipient.landlord?
        t("noti.messages.tenant_removed_landlord",
          tenant_name: params[:tenant_name],
          house: params[:house],
          floor: params[:floor],
          rental_unit: params[:rental_unit],
          default: "Đã xóa khách thuê %{tenant_name} ra khỏi %{house}, tầng %{floor}, %{rental_unit}.")
      else
        t("noti.messages.tenant_removed",
          house: params[:house],
          floor: params[:floor],
          rental_unit: params[:rental_unit])
      end
    end

    def url
      if recipient.landlord?
        landlord_house_tenants_path(params[:house_id])
      else
        tenant_room_path
      end
    end
  end
end
