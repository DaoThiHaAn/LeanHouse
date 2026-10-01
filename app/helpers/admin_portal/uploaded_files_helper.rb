# frozen_string_literal: true

module AdminPortal
  module UploadedFilesHelper
    RECORD_TYPE_I18N_KEYS = {
      "User" => "admin.uploaded_files.record_types.User",
      "Contract" => "admin.uploaded_files.record_types.Contract",
      "ServiceUsageLog" => "admin.uploaded_files.record_types.ServiceUsageLog",
      "Invoice" => "admin.uploaded_files.record_types.Invoice",
      "RepairRequest" => "admin.uploaded_files.record_types.RepairRequest",
      "VehicleRequest" => "admin.uploaded_files.record_types.VehicleRequest",
      "Vehicle" => "admin.uploaded_files.record_types.Vehicle",
      "House" => "admin.uploaded_files.record_types.House",
      "ActiveStorage::VariantRecord" => "admin.uploaded_files.record_types.VariantRecord"
    }.freeze

    RECORD_TYPE_BADGE_CLASSES = {
      "User" => "bg-primary-subtle text-primary border border-primary-subtle",
      "Contract" => "bg-purple-subtle text-purple border border-purple-subtle",
      "ServiceUsageLog" => "bg-info-subtle text-info-emphasis border border-info-subtle",
      "Invoice" => "bg-success-subtle text-success-emphasis border border-success-subtle",
      "RepairRequest" => "bg-warning-subtle text-warning-emphasis border border-warning-subtle",
      "VehicleRequest" => "bg-secondary-subtle text-secondary-emphasis border border-secondary-subtle",
      "Vehicle" => "bg-secondary-subtle text-secondary-emphasis border border-secondary-subtle",
      "House" => "bg-dark-subtle text-dark border border-dark-subtle",
      "ActiveStorage::VariantRecord" => "bg-secondary-subtle text-secondary border border-secondary-subtle"
    }.freeze

    ROLE_BADGE_I18N_KEYS = {
      "landlord" => "role.landlord",
      "tenant" => "role.tenant",
      "admin" => "role.admin",
      "super_admin" => "role.admin",
      "support" => "role.admin"
    }.freeze

    def find_senders_for_attachment(attachment)
      record = attachment.record
      return [] unless record

      if attachment.record_type == "ActiveStorage::VariantRecord" || record.is_a?(ActiveStorage::VariantRecord)
        original_attachment = find_original_attachment_for_variant(record)
        return (original_attachment && original_attachment != attachment ? find_senders_for_attachment(original_attachment) : [])
      end

      case record
      when User
        [ record ]
      when Contract
        [ record.landlord&.user || record.house&.landlord&.user ].compact
      when Vehicle
        [ record.tenant&.user ].compact
      when ServiceUsageLog
        senders_for_room_record(record, record.submitted_by)
      when Invoice
        senders_for_room_record(record, record.paid_by)
      when RepairRequest, VehicleRequest
        req = record.request
        [ req&.tenant&.user ].compact
      when House
        [ record.landlord.user ].compact
      else
        fallback_senders_for_record(record)
      end
    end

    def record_type_badge_text(record_type)
      key = RECORD_TYPE_I18N_KEYS[record_type.to_s]
      key ? I18n.t(key) : record_type.to_s
    end

    def user_role_badge_text(user)
      return "" unless user && user.respond_to?(:role)

      role_str = user.role.to_s
      key = ROLE_BADGE_I18N_KEYS[role_str]
      key ? I18n.t(key) : role_str.titleize
    end

    def record_friendly_description(attachment)
      record = attachment.record
      return "#{record_type_badge_text(attachment.record_type)} ##{attachment.record_id}" unless record

      case attachment.record_type
      when "User"
        "#{I18n.t('admin.uploaded_files.types.user_avatar')}: #{record.fullname.presence || I18n.t('admin.uploaded_files.record_types.User')}"
      when "Contract"
        "#{I18n.t('admin.uploaded_files.types.contract')}: #{record.name.presence || "##{record.id}"}"
      when "ServiceUsageLog"
        "#{I18n.t('admin.uploaded_files.types.service_usage_log')}: #{record.service_name} (#{record.room&.title_name || 'Phòng'})"
      when "Invoice"
        "#{I18n.t('admin.uploaded_files.types.invoice')}: #{record.title.presence || "##{record.id}"}"
      when "RepairRequest"
        "#{I18n.t('admin.uploaded_files.types.repair_request')}: #{record.title.presence || "##{record.id}"}"
      when "VehicleRequest", "Vehicle"
        type_key = attachment.record_type == "VehicleRequest" ? "vehicle_request" : "vehicle"
        "#{I18n.t("admin.uploaded_files.types.#{type_key}")}: #{record.license_plate.presence || record.id}"
      when "House"
        "#{I18n.t('admin.uploaded_files.types.house')}: #{record.name.presence || 'Nhà trọ'}"
      when "ActiveStorage::VariantRecord"
        if (orig = find_original_attachment_for_variant(record)) && orig != attachment
          "#{I18n.t('admin.uploaded_files.types.variant_of')}: #{record_friendly_description(orig)}"
        else
          I18n.t("admin.uploaded_files.types.variant_cached")
        end
      else
        "#{record_type_badge_text(attachment.record_type)} ##{attachment.record_id}"
      end
    end

    def record_type_badge_class(record_type)
      RECORD_TYPE_BADGE_CLASSES.fetch(record_type.to_s, "bg-light text-secondary border")
    end

    def file_type_badge(attachment)
      blob = attachment.blob
      return "".html_safe unless blob

      ct = blob.content_type.to_s
      if ct.start_with?("image/")
        ext = ct.split("/").last.upcase
        content_tag(:span, class: "badge bg-success-subtle text-success border border-success-subtle rounded-pill small d-inline-flex align-items-center gap-1") do
          concat content_tag(:span, "image", class: "material-symbols-outlined fs-6")
          concat "#{I18n.t('admin.uploaded_files.formats.image')} (#{ext})"
        end
      elsif ct.start_with?("video/")
        ext = ct.split("/").last.upcase
        content_tag(:span, class: "badge bg-danger-subtle text-danger border border-danger-subtle rounded-pill small d-inline-flex align-items-center gap-1") do
          concat content_tag(:span, "videocam", class: "material-symbols-outlined fs-6")
          concat "#{I18n.t('admin.uploaded_files.formats.video')} (#{ext})"
        end
      elsif ct == "application/pdf"
        content_tag(:span, class: "badge bg-warning-subtle text-warning-emphasis border border-warning-subtle rounded-pill small d-inline-flex align-items-center gap-1") do
          concat content_tag(:span, "picture_as_pdf", class: "material-symbols-outlined fs-6")
          concat "PDF"
        end
      else
        content_tag(:span, class: "badge bg-secondary-subtle text-secondary border border-secondary-subtle rounded-pill small d-inline-flex align-items-center gap-1") do
          concat content_tag(:span, "description", class: "material-symbols-outlined fs-6")
          concat I18n.t("admin.uploaded_files.formats.document")
        end
      end
    end

    def record_admin_link(attachment)
      record = attachment.record
      return nil unless record

      if attachment.record_type == "ActiveStorage::VariantRecord" || record.is_a?(ActiveStorage::VariantRecord)
        orig = find_original_attachment_for_variant(record)
        return (record_admin_link(orig) if orig && orig != attachment)
      end

      case record
      when User
        admin_user_path(record)
      when Contract
        admin_contract_path(record)
      when Invoice
        admin_invoice_path(record)
      when House
        admin_house_path(record)
      when RepairRequest, VehicleRequest
        admin_request_path(record)
      end
    end

    def record_admin_turbo_frame(attachment)
      record = attachment.record
      return "_top" unless record

      if attachment.record_type == "ActiveStorage::VariantRecord" || record.is_a?(ActiveStorage::VariantRecord)
        orig = find_original_attachment_for_variant(record)
        return (orig && orig != attachment ? record_admin_turbo_frame(orig) : "_top")
      end

      case record
      when Contract
        "contract_detail_modal"
      when Invoice
        "invoice_detail_modal"
      when RepairRequest, VehicleRequest
        "request_detail_modal"
      else
        "_top"
      end
    end

    private

    def find_original_attachment_for_variant(variant_record)
      return nil unless variant_record.respond_to?(:blob) && variant_record.blob

      variant_record.blob.attachments.find { |a| a.record_type != "ActiveStorage::VariantRecord" } || variant_record.blob.attachments.first
    end

    def senders_for_room_record(record, actor)
      return [ actor ] if actor
      return [] unless record.room

      landlord_user = record.room.house.landlord.user
      tenants = record.room.active_staying_tenant_users
      (tenants + [ landlord_user ]).compact.uniq
    end

    def fallback_senders_for_record(record)
      if record.respond_to?(:user) && record.user.is_a?(User)
        [ record.user ]
      elsif record.respond_to?(:submitted_by) && record.submitted_by.is_a?(User)
        [ record.submitted_by ]
      elsif record.respond_to?(:tenant) && record.tenant.respond_to?(:user)
        [ record.tenant.user ].compact
      elsif record.respond_to?(:landlord) && record.landlord.respond_to?(:user)
        [ record.landlord.user ].compact
      else
        []
      end
    end
  end
end
