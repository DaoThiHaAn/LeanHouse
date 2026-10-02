# frozen_string_literal: true

module Payments
  class PayosController < ApplicationController
    helper_method :tenant_can_access_invoice?

    def return
      handle_payment_return
    end

    def cancel
      params[:cancel] = "true"
      handle_payment_return
    end

    private

    def handle_payment_return
      @is_cancelled = params[:cancel].to_s == "true" || params[:status] == "CANCELLED"

      order_code = params[:orderCode]
      @payment_order = PaymentOrder.find_by(order_code: order_code) if order_code.present?
      @invoice = (@payment_order ? @payment_order.invoice : nil) || Invoice.find_by(id: params[:invoice_id])
      @payment_order ||= @invoice.payos_order if @invoice

      # Reconcile invoice with payOS if needed
      if @invoice.present? && !@is_cancelled
        if (@invoice.pending? || @invoice.overdue?) && (params[:status] == "PAID" || params[:code] == "00")
          PayosService.reconcile_payment!(@invoice)
        end
      end

      # Attempt origin switch if unauthenticated in development or local cross-host (e.g. localhost vs 127.0.0.1)
      if !logged_in?
        stored_base = @payment_order&.metadata.to_h["app_base_url"]
        local_hosts = [ "localhost", "127.0.0.1", "::1" ]

        if stored_base.present?
          stored_uri = URI(stored_base) rescue nil
          if stored_uri.present? && stored_uri.host != request.host
            if local_hosts.include?(request.host) && local_hosts.include?(stored_uri.host)
              redirect_to "#{stored_base}#{request.fullpath}", allow_other_host: true
              return
            end
          end
        elsif Rails.env.development? && request.host == "localhost" && params[:_checked_origin].blank?
          alt_url = "#{request.protocol}127.0.0.1:#{request.port}#{request.fullpath}"
          alt_url += (alt_url.include?("?") ? "&" : "?") + "_checked_origin=1"
          redirect_to alt_url, allow_other_host: true
          return
        end
      end

      # Redirect logged-in users to their invoice view if authorized
      if logged_in? && @invoice.present?
        if current_user.tenant? && tenant_can_access_invoice?(current_user, @invoice)
          if @is_cancelled
            redirect_to tenant_invoice_path(@invoice), alert: t("invoice.payos.payment_cancelled_flash")
          else
            redirect_to tenant_invoice_path(@invoice), notice: t("invoice.payos.payment_success_flash")
          end
          return
        elsif current_user.landlord? && current_user.id == @invoice.house.landlord_id
          if @is_cancelled
            redirect_to landlord_house_invoice_path(@invoice.house, @invoice), alert: t("invoice.payos.payment_cancelled_flash")
          else
            redirect_to landlord_house_invoice_path(@invoice.house, @invoice), notice: t("invoice.payos.payment_success_flash")
          end
          return
        elsif current_user.admin?
          redirect_to admin_invoice_path(@invoice), notice: t("invoice.payos.payment_success_flash")
          return
        end
      end

      # Render public payment result view for unauthenticated users or users without direct portal access
      render :return
    end

    def tenant_can_access_invoice?(user, invoice)
      tenant = user.tenant
      return false unless tenant

      linked_house_ids = tenant.linked_houses.pluck(:id)
      return false unless linked_house_ids.include?(invoice.house_id)

      staying_rooms = tenant.tenant_stays.includes(rental_unit: :rentable).filter_map do |stay|
        stay.rental_unit&.room&.id
      end

      if invoice.invoice_type == "room"
        staying_rooms.include?(invoice.room_id)
      else
        invoice.tenant_id == tenant.id || staying_rooms.include?(invoice.room_id)
      end
    rescue StandardError
      false
    end
  end
end
