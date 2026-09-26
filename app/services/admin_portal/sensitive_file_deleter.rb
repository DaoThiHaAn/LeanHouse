# frozen_string_literal: true

module AdminPortal
  class SensitiveFileDeleter
    def self.call(...)
      new(...).call
    end

    def initialize(attachment:, reason_param:, custom_reason_param:, helpers:)
      @attachment = attachment
      @reason_param = reason_param
      @custom_reason_param = custom_reason_param
      @helpers = helpers
    end

    def call
      filename = attachment.blob.filename.to_s
      reason = determine_deletion_reason
      record_info = helpers.record_friendly_description(attachment)
      recipients = helpers.find_senders_for_attachment(attachment)

      if recipients.any?
        SensitiveFileRemovedNotifier.with(
          filename: filename,
          reason: reason,
          record_info: record_info,
          record_type: attachment.record_type
        ).deliver_later(recipients)
      end

      attachment.purge
      filename
    end

    private

    attr_reader :attachment, :reason_param, :custom_reason_param, :helpers

    def determine_deletion_reason
      case reason_param
      when "sensitive_content"
        I18n.t("admin.uploaded_files.reasons.sensitive_content", default: "Nội dung nhạy cảm / không phù hợp")
      when "privacy_violation"
        I18n.t("admin.uploaded_files.reasons.privacy_violation", default: "Vi phạm quyền riêng tư / bản quyền")
      when "fraudulent_document"
        I18n.t("admin.uploaded_files.reasons.fraudulent_document", default: "Tài liệu không hợp lệ / nghi vấn giả mạo")
      when "malicious_content"
        I18n.t("admin.uploaded_files.reasons.malicious_content", default: "Tệp tin độc hại hoặc không an toàn")
      when "custom"
        custom_reason_param.presence || I18n.t("admin.uploaded_files.reasons.sensitive_content", default: "Nội dung không phù hợp với quy định hệ thống")
      else
        custom_reason_param.presence || reason_param.presence || I18n.t("admin.uploaded_files.reasons.sensitive_content", default: "Nội dung không phù hợp với quy chuẩn cộng đồng")
      end
    end
  end
end
