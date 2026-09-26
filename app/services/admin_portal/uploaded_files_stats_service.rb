# frozen_string_literal: true

module AdminPortal
  class UploadedFilesStatsService
    Result = Data.define(:total_files_count, :total_storage_bytes, :images_count, :videos_count, :documents_count)

    def self.call
      new.call
    end

    def call
      Result.new(
        total_files_count: ActiveStorage::Attachment.count,
        total_storage_bytes: ActiveStorage::Blob.sum(:byte_size),
        images_count: ActiveStorage::Blob.where("content_type LIKE ?", "image/%").count,
        videos_count: ActiveStorage::Blob.where("content_type LIKE ?", "video/%").count,
        documents_count: ActiveStorage::Blob.where(
          "content_type LIKE ? OR content_type = ?",
          "application/%",
          "text/%"
        ).count
      )
    end
  end
end
