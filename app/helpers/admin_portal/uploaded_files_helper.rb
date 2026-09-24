# frozen_string_literal: true

module AdminPortal
  module UploadedFilesHelper
    def find_senders_for_attachment(attachment)
      record = attachment.record
      return [] unless record

      case record
      when User
        [ record ]
      when Contract
        [ record.tenant&.user, record.house&.landlord&.user ].compact.uniq
      when ServiceUsageLog
        if record.submitted_by
          [ record.submitted_by ]
        elsif record.room
          landlord_user = record.room.house&.landlord&.user
          tenants = record.room.respond_to?(:active_staying_tenant_users) ? record.room.active_staying_tenant_users : []
          (tenants + [ landlord_user ]).compact.uniq
        else
          []
        end
      when Invoice
        if record.paid_by
          [ record.paid_by ]
        elsif record.room
          landlord_user = record.room.house&.landlord&.user
          tenants = record.room.respond_to?(:active_staying_tenant_users) ? record.room.active_staying_tenant_users : []
          (tenants + [ landlord_user ]).compact.uniq
        else
          []
        end
      when RepairRequest
        req = record.request
        [ req&.tenant&.user, req&.house&.landlord&.user ].compact.uniq
      when VehicleRequest
        req = record.request
        [ req&.tenant&.user, req&.house&.landlord&.user ].compact.uniq
      when Vehicle
        [ record.tenant&.user, record.house&.landlord&.user ].compact.uniq
      when House
        [ record.landlord&.user ].compact
      when ActiveStorage::VariantRecord
        original_attachment = record.blob&.attachments&.first
        if original_attachment && original_attachment != attachment
          find_senders_for_attachment(original_attachment)
        else
          []
        end
      else
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

    def record_type_badge_text(record_type)
      case record_type.to_s
      when "User"
        I18n.t("admin.uploaded_files.record_types.User")
      when "Contract"
        I18n.t("admin.uploaded_files.record_types.Contract")
      when "ServiceUsageLog"
        I18n.t("admin.uploaded_files.record_types.ServiceUsageLog")
      when "Invoice"
        I18n.t("admin.uploaded_files.record_types.Invoice")
      when "RepairRequest"
        I18n.t("admin.uploaded_files.record_types.RepairRequest")
      when "VehicleRequest"
        I18n.t("admin.uploaded_files.record_types.VehicleRequest")
      when "Vehicle"
        I18n.t("admin.uploaded_files.record_types.Vehicle")
      when "House"
        I18n.t("admin.uploaded_files.record_types.House")
      when "ActiveStorage::VariantRecord"
        I18n.t("admin.uploaded_files.record_types.VariantRecord")
      else
        record_type.to_s
      end
    end


    def user_role_badge_text(user)
      return "" unless user

      if user.respond_to?(:role)
        case user.role.to_s
        when "landlord"
          I18n.t("role.landlord")
        when "tenant"
          I18n.t("role.tenant")
        when "admin", "super_admin", "support"
          I18n.t("role.admin")
        else
          user.role.to_s.titleize
        end
      else
        ""
      end
    end

    def record_friendly_description(attachment)
      case attachment.record_type
      when "User"
        user = attachment.record
        "#{I18n.t('admin.uploaded_files.types.user_avatar')}: #{user&.fullname || I18n.t('admin.uploaded_files.record_types.User')}"
      when "Contract"
        contract = attachment.record
        "#{I18n.t('admin.uploaded_files.types.contract')}: #{contract&.try(:name) || "##{contract&.id}"}"
      when "ServiceUsageLog"
        log = attachment.record
        "#{I18n.t('admin.uploaded_files.types.service_usage_log')}: #{log&.service_name} (#{log&.room&.title_name || 'Phòng'})"
      when "Invoice"
        invoice = attachment.record
        "#{I18n.t('admin.uploaded_files.types.invoice')}: #{invoice&.try(:title) || "##{invoice&.id}"}"
      when "RepairRequest"
        req = attachment.record
        "#{I18n.t('admin.uploaded_files.types.repair_request')}: #{req&.try(:title) || "##{req&.id}"}"
      when "VehicleRequest"
        req = attachment.record
        "#{I18n.t('admin.uploaded_files.types.vehicle_request')}: #{req&.license_plate || req&.id}"
      when "Vehicle"
        veh = attachment.record
        "#{I18n.t('admin.uploaded_files.types.vehicle')}: #{veh&.license_plate || veh&.id}"
      when "House"
        house = attachment.record
        "#{I18n.t('admin.uploaded_files.types.house')}: #{house&.name || 'Nhà trọ'}"
      when "ActiveStorage::VariantRecord"
        "#{I18n.t('admin.uploaded_files.types.variant')}: #{attachment.blob&.filename}"
      else
        "#{record_type_badge_text(attachment.record_type)} ##{attachment.record_id}"
      end
    end

    def record_type_badge_class(record_type)
      case record_type
      when "User"
        "bg-primary-subtle text-primary border border-primary-subtle"
      when "Contract"
        "bg-purple-subtle text-purple border border-purple-subtle"
      when "ServiceUsageLog"
        "bg-info-subtle text-info-emphasis border border-info-subtle"
      when "Invoice"
        "bg-success-subtle text-success-emphasis border border-success-subtle"
      when "RepairRequest"
        "bg-warning-subtle text-warning-emphasis border border-warning-subtle"
      when "VehicleRequest", "Vehicle"
        "bg-secondary-subtle text-secondary-emphasis border border-secondary-subtle"
      when "House"
        "bg-dark-subtle text-dark border border-dark-subtle"
      when "ActiveStorage::VariantRecord"
        "bg-secondary-subtle text-secondary border border-secondary-subtle"
      else
        "bg-light text-secondary border"
      end
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
      else
        nil
      end
    end
  end
end
