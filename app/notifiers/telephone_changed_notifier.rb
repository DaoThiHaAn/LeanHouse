class TelephoneChangedNotifier < ApplicationNotifier
  required_param :new_tel

  notification_methods do
    def title
      t("noti.titles.tel_changed")
    end

    def message
      t("noti.messages.tel_changed", new_tel: params[:new_tel])
    end

    def url
      if recipient.landlord?
        landlord_profile_path
      else
        tenant_profile_path
      end
    end
  end
end

