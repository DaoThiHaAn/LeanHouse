class TenantPortal::InvoicesController < TenantPortal::BaseController
  before_action :set_room

  def index
    @invoices = @house.invoices
                      .where("(invoices.invoice_type = 'room' AND invoices.room_id = :room_id) OR (invoices.invoice_type = 'individual' AND invoices.tenant_id = :tenant_id)", room_id: @room.id, tenant_id: @tenant.id)
                      .kept
                      .includes(:room, :tenant, :bank_account)

    if params[:month].present?
      month = Date.parse("#{params[:month]}-01") rescue nil
      @invoices = @invoices.for_month(month) if month
    end

    if params[:status].present? && Invoice.statuses.key?(params[:status])
      @invoices = @invoices.where(status: params[:status])
    end

    @invoices = @invoices.sorted
  end

  def show
    @invoice = find_tenant_invoice
    @items = @invoice.invoice_items.order(created_at: :asc)
    @bank_account = @invoice.bank_account
  end

  def mark_paid
    @invoice = find_tenant_invoice

    if @invoice.paid?
      redirect_to tenant_invoice_path(@invoice), alert: t("invoice.already_paid", default: "Hóa đơn này đã được thanh toán.")
      return
    end

    Invoices::MarkPaidService.call(
      invoice: @invoice,
      paid_by: current_user,
      params: payment_params
    )

    redirect_to tenant_invoice_path(@invoice), notice: t("invoice.payment_submitted_success", default: "Đã gửi xác nhận thanh toán thành công!")
  end

  private

  def find_tenant_invoice
    @house.invoices
          .where("(invoices.invoice_type = 'room' AND invoices.room_id = :room_id) OR (invoices.invoice_type = 'individual' AND invoices.tenant_id = :tenant_id)", room_id: @room.id, tenant_id: @tenant.id)
          .find(params[:id])
  end

  def payment_params
    params.fetch(:invoice, params).permit(:payment_method, :payment_proof, :note)
  end

  def set_room
    @room = @tenant_stay.rental_unit.room
  end
end
