module Invoices
  class IssueService
    def self.call(room:, billing_month:, landlord:, params:)
      new(room: room, billing_month: billing_month, landlord: landlord, params: params).call
    end

    def initialize(room:, billing_month:, landlord:, params:)
      @room = room
      @house = room.house
      @billing_month = billing_month.to_date.beginning_of_month
      @landlord = landlord
      @params = params
      @inv_type = params[:invoice_type].presence || "room"
    end

    def call
      if @inv_type == "individual"
        issue_individual_invoices
      else
        [ issue_room_invoice ]
      end
    end

    private

    def issue_room_invoice
      ActiveRecord::Base.transaction do
        code = Invoice.generate_code(@room, Date.current)
        start_date = @params[:start_date].presence || @billing_month.beginning_of_month
        end_date = @params[:end_date].presence || @billing_month.end_of_month

        invoice = Invoice.create!(
          code: code,
          title: @params[:title].presence || I18n.t("invoice.default_title", default: "Thu tiền hàng tháng"),
          house: @house,
          room: @room,
          tenant_id: nil,
          bank_account_id: @params[:bank_account_id].presence,
          created_by: @landlord,
          invoice_type: "room",
          billing_month: @billing_month,
          start_date: start_date,
          end_date: end_date,
          due_date: @params[:due_date].presence || (Date.current + 5.days),
          note: @params[:note].presence
        )

        build_invoice_items(invoice, record_usage_log: true)
        finalize_invoice(invoice)
        notify_tenants(invoice)

        invoice
      end
    end

    def issue_individual_invoices
      staying_tenants = if @house.bed?
                          @room.all_staying_bed_tenants.map { |i| i[:tenant] }.compact.uniq
      else
                          @room.all_staying_tenants.compact.uniq
      end

      if staying_tenants.empty?
        raise ArgumentError, I18n.t("invoice.errors.no_staying_tenants_in_room")
      end

      created_invoices = []

      ActiveRecord::Base.transaction do
        staying_tenants.each_with_index do |tenant, idx|
          code = Invoice.generate_code(@room, Date.current)
          start_date = @params[:start_date].presence || @billing_month.beginning_of_month
          end_date = @params[:end_date].presence || @billing_month.end_of_month

          invoice = Invoice.create!(
            code: code,
            title: @params[:title].presence || I18n.t("invoice.default_title", default: "Thu tiền hàng tháng"),
            house: @house,
            room: @room,
            tenant_id: tenant.id,
            bank_account_id: @params[:bank_account_id].presence,
            created_by: @landlord,
            invoice_type: "individual",
            billing_month: @billing_month,
            start_date: start_date,
            end_date: end_date,
            due_date: @params[:due_date].presence || (Date.current + 5.days),
            note: @params[:note].presence
          )

          build_invoice_items(invoice, record_usage_log: (idx == 0), tenant: tenant)
          finalize_invoice(invoice)
          notify_tenants(invoice)

          created_invoices << invoice
        end
      end

      created_invoices
    end

    def build_invoice_items(invoice, record_usage_log: true, tenant: nil)
      subtotal = 0
      total_discount = 0
      total_addition = 0

      raw_items = @params[:items] || []
      items_list = raw_items.respond_to?(:values) ? raw_items.values : Array(raw_items)

      items_list.each do |item_param|
        selected = item_param[:selected].to_s == "1" || item_param[:selected] == true || item_param[:selected].to_s == "true"
        next unless selected

        item_type = item_param[:item_type].to_s
        name = item_param[:name].to_s.strip
        next if name.blank? && %w[addition discount].include?(item_type)
        next if name.blank?

        qty = item_param[:quantity].to_f
        unit_price = item_param[:unit_price].to_i
        unit = item_param[:unit].to_s.strip
        amount = item_param[:amount].present? ? item_param[:amount].to_i : (qty * unit_price).round
        item_start_date = item_param[:start_date].presence || invoice.start_date
        item_end_date = item_param[:end_date].presence || invoice.end_date
        prev_rd = item_param[:prev_reading].presence&.to_i
        latest_rd = item_param[:latest_reading].presence&.to_i

        # If bed house and item is rent, adjust rent specifically for this tenant's bed if applicable
        if @house.bed? && item_type == "rent" && tenant.present?
          stay = @house.tenant_stay_for(tenant.id)
          bed_rent = stay&.rental_unit&.rent
          if bed_rent.present? && bed_rent > 0
            unit_price = bed_rent
            amount = bed_rent
            location = stay&.rental_unit&.location_info || "#{@room.title_name} (Giường)"
            name = "Tiền thuê #{location}"
          end
        end

        # Handle metered service log linking or creation (once per room & billing month)
        if item_type == "metered_service"
          variant_id = item_param[:service_variant_id]
          variant = ServiceVariant.find_by(id: variant_id)
          log = nil

          if record_usage_log
            if item_param[:latest_reading].present?
              log = @room.service_usage_logs.find_or_initialize_by(
                service_id: variant&.service_id,
                billing_month: @billing_month
              )
              log.service_variant = variant
              log.service_name = name
              log.unit = unit
              log.unit_price = unit_price
              log.start_date ||= item_start_date
              log.end_date ||= item_end_date
              log.prev_reading = prev_rd || 0
              log.latest_reading = latest_rd
              log.is_confirmed = true
              log.confirmed_at ||= Time.current
              log.confirmed_by ||= @landlord
              log.save!
            elsif item_param[:service_usage_log_id].present?
              log = ServiceUsageLog.find_by(id: item_param[:service_usage_log_id])
            end
          else
            log = if item_param[:service_usage_log_id].present?
                    ServiceUsageLog.find_by(id: item_param[:service_usage_log_id])
            else
                    @room.service_usage_logs.find_by(
                      service_id: variant&.service_id,
                      billing_month: @billing_month
                    )
            end
          end

          if log.present? && !invoice.service_usage_logs.include?(log)
            invoice.service_usage_logs << log
          end
        end

        invoice.invoice_items.create!(
          service_variant_id: item_param[:service_variant_id].presence,
          item_type: item_type,
          name: name,
          unit: unit.presence,
          unit_price: unit_price,
          quantity: qty,
          amount: amount,
          start_date: item_start_date,
          end_date: item_end_date,
          prev_reading: prev_rd,
          latest_reading: latest_rd,
          note: item_param[:note].presence
        )

        case item_type
        when "discount"
          total_discount += amount.abs
        when "addition"
          total_addition += amount.abs
        else
          subtotal += amount
        end
      end

      invoice.subtotal = subtotal
      invoice.total_discount = total_discount
      invoice.total_addition = total_addition
      invoice.total_amount = [ subtotal + total_addition - total_discount, 0 ].max
    end

    def finalize_invoice(invoice)
      mode = @params[:transfer_note_mode].presence || "system"
      transfer_note = case mode
      when "none"
                        nil
      when "custom"
                        @params[:transfer_note].presence
      else
                        TransferNoteBuilder.build(@house.transfer_note_template, invoice)
      end

      invoice.update!(
        transfer_note: transfer_note
      )
    end

    def notify_tenants(invoice)
      tenant_users = invoice.target_users
      if tenant_users.present? && tenant_users.any?
        InvoiceIssuedNotifier.with(
          invoice: invoice,
          invoice_id: invoice.id,
          code: invoice.code,
          room_name: @room.title_name,
          month: invoice.billing_month.strftime("%m/%Y"),
          raw_month: invoice.billing_month.strftime("%Y-%m"),
          amount: ApplicationController.helpers.format_money(invoice.total_amount),
          due_date: invoice.due_date.strftime("%d/%m/%Y"),
          house_id: @house.id
        ).deliver_later(tenant_users)
      end
    end
  end
end
