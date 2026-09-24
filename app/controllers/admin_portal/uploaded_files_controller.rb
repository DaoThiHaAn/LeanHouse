# frozen_string_literal: true

module AdminPortal
  class UploadedFilesController < BaseController
    before_action :set_attachment, only: %i[show destroy]

    def index
      @record_type_filter = params[:record_type].presence || "all"
      @file_type_filter = params[:file_type].presence || "all"
      @query = params[:q].presence

      # Global stats across all attachments
      @total_files_count = ActiveStorage::Attachment.count
      @total_storage_bytes = ActiveStorage::Blob.sum(:byte_size)
      @images_count = ActiveStorage::Blob.where("content_type LIKE ?", "image/%").count
      @videos_count = ActiveStorage::Blob.where("content_type LIKE ?", "video/%").count
      @documents_count = ActiveStorage::Blob.where("content_type LIKE ? OR content_type = ?", "application/%", "text/%").count

      scope = ActiveStorage::Attachment.joins(:blob).includes(:blob)

      if @record_type_filter != "all" && allowed_record_types.include?(@record_type_filter)
        scope = scope.where(record_type: @record_type_filter)
      end

      case @file_type_filter
      when "image"
        scope = scope.where("active_storage_blobs.content_type LIKE ?", "image/%")
      when "video"
        scope = scope.where("active_storage_blobs.content_type LIKE ?", "video/%")
      when "pdf"
        scope = scope.where("active_storage_blobs.content_type = ?", "application/pdf")
      when "document"
        scope = scope.where("active_storage_blobs.content_type LIKE ? OR active_storage_blobs.content_type LIKE ?", "application/%", "text/%")
      end

      if @query.present?
        sanitized = "%#{ActiveRecord::Base.sanitize_sql_like(@query.strip)}%"
        scope = scope.where("active_storage_blobs.filename ILIKE ? OR active_storage_attachments.record_type ILIKE ?", sanitized, sanitized)
      end

      @attachments = scope.order(created_at: :desc).page(params[:page]).per(20)

      if turbo_frame_request?
        render partial: "table"
      end
    end

    def show
      render layout: false if turbo_frame_request?
    end

    def destroy
      reason = determine_deletion_reason
      filename = @attachment.blob.filename.to_s
      record_info = helpers.record_friendly_description(@attachment)
      recipients = helpers.find_senders_for_attachment(@attachment)

      # Notify uploader / sender before purging
      if recipients.any?
        SensitiveFileRemovedNotifier.with(
          filename: filename,
          reason: reason,
          record_info: record_info,
          record_type: @attachment.record_type
        ).deliver_later(recipients)
      end

      @attachment.purge

      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = t("admin.uploaded_files.delete_success", filename: filename, default: "Đã gỡ bỏ tệp \"#{filename}\" thành công và gửi thông báo tới người dùng!")
          render turbo_stream: [
            turbo_stream.remove(helpers.dom_id(@attachment)),
            turbo_stream.update("flash", partial: "layouts/shared_components/flash_message")
          ]
        end
        format.html do
          redirect_to admin_uploaded_files_path,
                      notice: t("admin.uploaded_files.delete_success", filename: filename, default: "Đã gỡ bỏ tệp \"#{filename}\" thành công và gửi thông báo tới người dùng!")
        end
      end
    end

    private

    def set_attachment
      @attachment = ActiveStorage::Attachment.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_uploaded_files_path, alert: t("admin.uploaded_files.not_found", default: "Không tìm thấy tệp này hoặc tệp đã bị xóa.")
    end

    def allowed_record_types
      %w[User Contract ServiceUsageLog Invoice RepairRequest VehicleRequest Vehicle House ActiveStorage::VariantRecord]
    end


    def determine_deletion_reason
      case params[:reason]
      when "sensitive_content"
        t("admin.uploaded_files.reasons.sensitive_content", default: "Nội dung nhạy cảm / không phù hợp")
      when "privacy_violation"
        t("admin.uploaded_files.reasons.privacy_violation", default: "Vi phạm quyền riêng tư / bản quyền")
      when "fraudulent_document"
        t("admin.uploaded_files.reasons.fraudulent_document", default: "Tài liệu không hợp lệ / nghi vấn giả mạo")
      when "malicious_content"
        t("admin.uploaded_files.reasons.malicious_content", default: "Tệp tin độc hại hoặc không an toàn")
      when "custom"
        params[:custom_reason].presence || t("admin.uploaded_files.reasons.sensitive_content", default: "Nội dung không phù hợp với quy định hệ thống")
      else
        params[:custom_reason].presence || params[:reason].presence || t("admin.uploaded_files.reasons.sensitive_content", default: "Nội dung không phù hợp với quy chuẩn cộng đồng")
      end
    end
  end
end
