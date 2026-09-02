module Invoices
  class IssueService
    def self.call(room:, billing_month:, landlord:, params:)
      month = billing_month.to_date.beginning_of_month

      ActiveRecord::Base.transaction do
        code = Invoice.generate_code(room, month)

        start_date = params[:start_date].presence || month.beginning_of_month
        end_date = params[:end_date].presence || month.end_of_month

        invoice = Invoice.create!(
          code: code,
          title: params[:title].presence || "Thu tiền hàng tháng",
          house: room.house,
          room: room,
          tenant_id: params[:tenant_id].presence,
          bank_account_id: params[:bank_account_id].presence,
          created_by: landlord,
          invoice_type: params[:invoice_type].presence || "room",
          billing_month: month,
          start_date: start_date,
          end_date: end_date,
          due_date: params[:due_date].presence || (Date.current + 5.days),
          note: params[:note].presence
        )

        subtotal = 0
        total_discount = 0
        total_addition = 0

        raw_items = params[:items] || []
        # If passed as hash or ActionController::Parameters (e.g. params[:items] = {"0" => {...}, "item_123" => {...}})
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
          item_start_date = item_param[:start_date].presence || start_date
          item_end_date = item_param[:end_date].presence || end_date
          prev_rd = item_param[:prev_reading].presence&.to_i
          latest_rd = item_param[:latest_reading].presence&.to_i

          # Handle metered service log linking or creation
          if item_type == "metered_service"
            variant_id = item_param[:service_variant_id]
            variant = ServiceVariant.find_by(id: variant_id)

            if item_param[:latest_reading].present?
              log = room.service_usage_logs.find_or_initialize_by(
                service_id: variant&.service_id,
                billing_month: month
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
              log.confirmed_by ||= landlord
              log.invoice = invoice
              log.save!
            elsif item_param[:service_usage_log_id].present?
              ServiceUsageLog.where(id: item_param[:service_usage_log_id]).update_all(invoice_id: invoice.id)
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

        total_amount = [ subtotal + total_addition - total_discount, 0 ].max
        transfer_note = TransferNoteBuilder.build(room.house.transfer_note_template, invoice)

        invoice.update!(
          subtotal: subtotal,
          total_discount: total_discount,
          total_addition: total_addition,
          total_amount: total_amount,
          transfer_note: transfer_note
        )

        # Deliver notification to target tenants
        tenant_users = invoice.target_users
        if tenant_users.present? && tenant_users.any?
          InvoiceIssuedNotifier.with(
            invoice: invoice,
            code: invoice.code,
            room_name: room.title_name,
            month: invoice.billing_month.strftime("%m/%Y"),
            raw_month: invoice.billing_month.strftime("%Y-%m"),
            amount: invoice.formatted_total_amount,
            due_date: invoice.due_date.strftime("%d/%m/%Y"),
            house_id: room.house_id
          ).deliver_later(tenant_users)
        end

        invoice
      end
    end
  end
end
