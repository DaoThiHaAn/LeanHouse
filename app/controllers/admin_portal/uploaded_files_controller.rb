# frozen_string_literal: true

module AdminPortal
  class UploadedFilesController < BaseController
    before_action :set_attachment, only: %i[show destroy]

    def index
      @record_type_filter = params[:record_type].presence || "all"
      @file_type_filter = params[:file_type].presence || "all"
      @query = params[:q].presence

      @stats = UploadedFilesStatsService.call
      @total_files_count = @stats.total_files_count
      @total_storage_bytes = @stats.total_storage_bytes
      @images_count = @stats.images_count
      @videos_count = @stats.videos_count
      @documents_count = @stats.documents_count

      @attachments = UploadedFilesFilter.call(params: params)

      render partial: "table" if turbo_frame_request?
    end

    def show
      render layout: false if turbo_frame_request?
    end

    def destroy
      filename = SensitiveFileDeleter.call(
        attachment: @attachment,
        reason_param: params[:reason],
        custom_reason_param: params[:custom_reason],
        helpers: helpers
      )

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
  end
end
