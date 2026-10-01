# frozen_string_literal: true

module AdminPortal
  class UploadedFilesStatsService
    Result = Data.define(:total_files_count, :total_storage_bytes, :images_count, :videos_count, :documents_count)

    def self.call
      new.call
    end

    def call
      base_attachments = ActiveStorage::Attachment.where.not(record_type: "ActiveStorage::VariantRecord")
      non_variant_blob_ids = base_attachments.select(:blob_id)

      Result.new(
        total_files_count: base_attachments.count,
        total_storage_bytes: ActiveStorage::Blob.sum(:byte_size),
        images_count: ActiveStorage::Blob.where(id: non_variant_blob_ids).where("content_type LIKE ?", "image/%").count,
        videos_count: ActiveStorage::Blob.where(id: non_variant_blob_ids).where("content_type LIKE ?", "video/%").count,
        documents_count: ActiveStorage::Blob.where(id: non_variant_blob_ids).where(
          "content_type LIKE ? OR content_type = ?",
          "application/%",
          "text/%"
        ).count
      )
    end
  end
end
