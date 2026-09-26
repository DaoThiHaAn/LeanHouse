# frozen_string_literal: true

module AdminPortal
  class UploadedFilesFilter
    FILES_PER_PAGE = 15

    ALLOWED_RECORD_TYPES = %w[
      User Contract ServiceUsageLog Invoice RepairRequest VehicleRequest Vehicle House ActiveStorage::VariantRecord
    ].freeze

    def self.call(...)
      new(...).call
    end

    def initialize(params:)
      @record_type = params[:record_type].presence || "all"
      @file_type = params[:file_type].presence || "all"
      @query = params[:q].presence
      @page = params[:page]
    end

    def call
      scope = base_scope
      scope = apply_record_type(scope)
      scope = apply_file_type(scope)
      scope = apply_search(scope)

      scope.order(created_at: :desc).page(page).per(FILES_PER_PAGE)
    end

    private

    attr_reader :record_type, :file_type, :query, :page

    def base_scope
      ActiveStorage::Attachment.joins(:blob).includes(:blob)
    end

    def apply_record_type(scope)
      return scope if record_type == "all" || !ALLOWED_RECORD_TYPES.include?(record_type)

      scope.where(record_type: record_type)
    end

    def apply_file_type(scope)
      case file_type
      when "image"
        scope.where("active_storage_blobs.content_type LIKE ?", "image/%")
      when "video"
        scope.where("active_storage_blobs.content_type LIKE ?", "video/%")
      when "pdf"
        scope.where("active_storage_blobs.content_type = ?", "application/pdf")
      when "document"
        scope.where(
          "active_storage_blobs.content_type LIKE ? OR active_storage_blobs.content_type LIKE ?",
          "application/%",
          "text/%"
        )
      else
        scope
      end
    end

    def apply_search(scope)
      return scope if query.blank?

      sanitized = "%#{ActiveRecord::Base.sanitize_sql_like(query.strip)}%"
      scope.where(
        "active_storage_blobs.filename ILIKE ? OR active_storage_attachments.record_type ILIKE ?",
        sanitized,
        sanitized
      )
    end
  end
end
