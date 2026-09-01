module Invoices
  class IssueService
    def self.call(room:, billing_month:, landlord:, params:)
      month = billing_month.to_date.beginning_of_month

      ActiveRecord::Base.transaction do
        code = Invoice.generate_code(room, month)

        invoice = Invoice.create!(
          code: code,
          house: room.house,
          room: room,
          tenant_id: params[:tenant_id].presence,
          bank_account_id: params[:bank_account_id].presence,
          created_by: landlord,
          invoice_type: params[:invoice_type].presence || "room",
          billing_month: month,
          due_date: params[:due_date].presence || (Date.current + 5.days),
          note: params[:note].presence
        )

        subtotal = 0
        total_discount = 0
        total_addition = 0

        raw_items = params[:items] || []
        # If passed as hash from form (e.g. params[:items] = {"0" => {...}, "1" => {...}})
        items_list = raw_items.is_a?(Hash) ? raw_items.values : Array(raw_items)

        items_list.each do |item_param|
          selected = item_param[:selected].to_s == "1" || item_param[:selected] == true || item_param[:selected].to_s == "true"
          next unless selected

          qty = item_param[:quantity].to_f
          unit_price = item_param[:unit_price].to_i
          item_type = item_param[:item_type].to_s
          name = item_param[:name].to_s.strip
          unit = item_param[:unit].to_s.strip
          amount = item_param[:amount].present? ? item_param[:amount].to_i : (qty * unit_price).round

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
              log.start_date ||= month.beginning_of_month
              log.end_date ||= month.end_of_month
              log.prev_reading = item_param[:prev_reading].to_i
              log.latest_reading = item_param[:latest_reading].to_i
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
            amount: amount
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

        invoice
      end
    end
  end
end
