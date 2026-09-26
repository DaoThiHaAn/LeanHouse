# frozen_string_literal: true

module Payments
  class PayosController < ApplicationController
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

      staying_rooms = tenant.tenant_stays.staying.includes(rental_unit: :rentable).map do |stay|
        stay.rental_unit.room.id
      end.compact

      (invoice.invoice_type == "room" && staying_rooms.include?(invoice.room_id)) ||
        (invoice.tenant_id == tenant.id)
    rescue StandardError
      false
    end
  end
end
