module Invoices
  class CreateCustomService
    Result = Struct.new(:success?, :invoices, :error_message, keyword_init: true)

    def self.call(house:, landlord:, params:)
      new(house: house, landlord: landlord, params: params).call
    end

    def initialize(house:, landlord:, params:)
      @house = house
      @landlord = landlord
      @params = params
    end

    def call
      tenant_ids = Array(@params[:tenant_ids]).reject(&:blank?).map(&:to_i).uniq
      if tenant_ids.empty?
        return Result.new(
          success?: false,
          invoices: [],
          error_message: I18n.t("invoice.errors.no_tenants_selected", default: "Vui lòng chọn ít nhất một người thuê để xuất hóa đơn.")
        )
      end

      valid_items = extract_valid_items
      if valid_items.empty?
        return Result.new(
          success?: false,
          invoices: [],
          error_message: I18n.t("invoice.errors.no_items_entered", default: "Vui lòng nhập ít nhất một khoản thu hoặc giảm trừ hợp lệ.")
        )
      end

      # Verify all tenants have active stays in the house
      target_stays = []
      tenant_ids.each do |tid|
        stay = @house.tenant_stay_for(tid)
        unless stay
          return Result.new(
            success?: false,
            invoices: [],
            error_message: I18n.t("invoice.errors.tenant_not_found", default: "Người thuê ID #{tid} không hợp lệ hoặc không còn lưu trú tại nhà này.")
          )
        end
        target_stays << stay
      end

      month = parse_month(@params[:billing_month])
      start_date = @params[:start_date].presence || month.beginning_of_month
      end_date = @params[:end_date].presence || month.end_of_month
      due_date = @params[:due_date].presence || (Date.current + 5.days)
      title = @params[:title].presence || I18n.t("invoice.default_custom_title", default: "Hóa đơn thu phí")
      note = @params[:note].presence
      bank_account_id = @params[:bank_account_id].presence

      created_invoices = []

      ActiveRecord::Base.transaction do
        target_stays.each do |stay|
          tenant = stay.tenant
          room = stay.rental_unit.room
          code = Invoice.generate_code(room, month)
          code = Invoice.generate_code(room, Date.current)

          invoice = Invoice.create!(
            code: code,
            title: title,
            house: @house,
            room: room,
            tenant: tenant,
            bank_account_id: bank_account_id,
            created_by: @landlord,
            invoice_type: "custom",
            billing_month: month,
            start_date: start_date,
            end_date: end_date,
            due_date: due_date,
            note: note
          )

          total_addition = 0
          total_discount = 0

          valid_items.each do |item|
            invoice.invoice_items.create!(
              item_type: item[:item_type],
              name: item[:name],
              unit: item[:unit],
              unit_price: item[:unit_price],
              quantity: item[:quantity],
              amount: item[:amount],
              start_date: start_date,
              end_date: end_date,
              note: item[:note]
            )

            if item[:item_type] == "discount"
              total_discount += item[:amount]
            else
              total_addition += item[:amount]
            end
          end

          total_amount = [ total_addition - total_discount, 0 ].max
          transfer_note = TransferNoteBuilder.build(@house.transfer_note_template, invoice)
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
            subtotal: 0,
            total_discount: total_discount,
            total_addition: total_addition,
            total_amount: total_amount,
            transfer_note: transfer_note
          )

          # Notify tenant
          tenant_users = invoice.target_users
          if tenant_users.present? && tenant_users.any?
            InvoiceIssuedNotifier.with(
              invoice: invoice,
              invoice_id: invoice.id,
              code: invoice.code,
              room_name: room.title_name,
              month: invoice.billing_month.strftime("%m/%Y"),
              raw_month: invoice.billing_month.strftime("%Y-%m"),
              amount: ApplicationController.helpers.format_money(invoice.total_amount),
              due_date: invoice.due_date.strftime("%d/%m/%Y"),
              house_id: @house.id
            ).deliver_later(tenant_users)
          end

          created_invoices << invoice
        end
      end

      Result.new(success?: true, invoices: created_invoices, error_message: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, invoices: [], error_message: e.record.errors.full_messages.to_sentence)
    rescue StandardError => e
      Result.new(success?: false, invoices: [], error_message: e.message)
    end

    private

    def extract_valid_items
      raw_items = @params[:items] || []
      items_list = raw_items.respond_to?(:values) ? raw_items.values : Array(raw_items)

      items_list.filter_map do |raw_item|
        item = raw_item.respond_to?(:to_unsafe_h) ? raw_item.to_unsafe_h : raw_item.to_h
        item = item.symbolize_keys

        selected = item[:selected].nil? || item[:selected].to_s == "1" || item[:selected] == true || item[:selected].to_s == "true"
        next unless selected

        name = item[:name].to_s.strip
        next if name.blank?

        unit_price = item[:unit_price].to_i
        quantity = item[:quantity].present? ? item[:quantity].to_f : 1.0
        amount = if item[:amount].present? && item[:amount].to_i != 0
                   item[:amount].to_i.abs
        else
                   (quantity * unit_price).round.abs
        end

        next if amount == 0 && unit_price == 0

        unit_price = amount if unit_price == 0 && quantity == 1.0

        item_type = item[:item_type].presence || "addition"
        item_type = "addition" unless %w[addition discount].include?(item_type)

        {
          item_type: item_type,
          name: name,
          unit: item[:unit].presence,
          unit_price: unit_price,
          quantity: quantity,
          amount: amount,
          note: item[:note].presence
        }
      end
    end

    def parse_month(str)
      return Date.current.beginning_of_month if str.blank?

      str_val = str.to_s.strip
      if str_val.match?(/\A\d{4}-\d{2}\z/)
        Date.parse("#{str_val}-01").beginning_of_month
      else
        Date.parse(str_val).beginning_of_month
      end
    rescue StandardError
      Date.current.beginning_of_month
    end
  end
end
