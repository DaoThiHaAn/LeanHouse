class TenantPortal::InvoicesController < TenantPortal::BaseController
  before_action :set_room
  before_action :set_invoice, only: %i[show mark_paid]

  def index
    @invoices = Invoices::FilterService.call(
      house: @house,
      params: params,
      tenant: @tenant,
      tenant_room_ids: tenant_current_house_room_ids
    ).page(params[:page]).per(10)
  end

  def show
    @items = @invoice.invoice_items.order(created_at: :asc)
    @bank_account = @invoice.bank_account
  end

  def mark_paid
    if @invoice.paid?
      respond_to do |format|
        format.turbo_stream do
          flash.now[:alert] = t("invoice.already_paid", default: "Hóa đơn này đã được thanh toán.")
          render :mark_paid, status: :unprocessable_entity
        end
        format.html do
          redirect_back fallback_location: tenant_invoice_path(@invoice),
                        alert: t("invoice.already_paid", default: "Hóa đơn này đã được thanh toán.")
        end
      end
      return
    end

    Invoices::MarkPaidService.call(
      invoice: @invoice,
      paid_by: current_user,
      params: payment_params
    )

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = t("invoice.payment_submitted_success", default: "Đã gửi xác nhận thanh toán thành công!")
      end
      format.html do
        redirect_back fallback_location: tenant_invoice_path(@invoice),
                      notice: t("invoice.payment_submitted_success", default: "Đã gửi xác nhận thanh toán thành công!")
      end
    end
  end

  private

  def set_invoice
    tenant_room_ids = tenant_current_house_room_ids
    @invoice = @house.invoices
                     .where(
                       "(invoices.invoice_type = 'room' AND invoices.room_id IN (:room_ids)) OR (invoices.invoice_type = 'individual' AND invoices.tenant_id = :tenant_id)",
                       room_ids: tenant_room_ids,
                       tenant_id: @tenant.id
                     )
                     .find(params[:id])
  end

  def tenant_current_house_room_ids
    stays_room_ids = @tenant.tenant_stays.includes(rental_unit: :rentable).map do |stay|
      ru = stay.rental_unit
      ru&.room&.id if ru&.house&.id == @house.id
    end.compact
    ([ @room.id ] + stays_room_ids).uniq
  end

  def payment_params
    params.fetch(:invoice, params).permit(:payment_method, :payment_proof, :note)
  end

  def set_room
    @room = @tenant_stay.rental_unit.room
  end
end
