class TenantRemovedNotifier < ApplicationNotifier
  required_param :tenant_stay

  notification_methods do
    def title
      t("noti.titles.rem_from_house")
    end

    def message
      t("noti.messages.tenant_removed",
        house: params[:house],
        floor: params[:floor],
        rental_unit:  params[:rental_unit])
    end

    def url
      tenant_room_path
    end
  end
end
