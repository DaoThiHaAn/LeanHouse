# frozen_string_literal: true

class SensitiveFileRemovedNotifier < ApplicationNotifier
  required_params :filename, :reason, :record_info


  notification_methods do
    def title
      I18n.t("noti.titles.sensitive_file_removed", default: "Tệp tải lên đã bị gỡ bỏ do nội dung nhạy cảm")
    end

    def message
      I18n.t(
        "noti.messages.sensitive_file_removed",
        filename: params[:filename],
        record_info: params[:record_info],
        reason: params[:reason],
        default: "Tệp \"#{params[:filename]}\" (#{params[:record_info]}) đã bị Quản trị viên gỡ bỏ do vi phạm quy định về nội dung (#{params[:reason]})."
      )
    end

    def url
      nil
    end

    def category
      "system"
    end
  end
end
