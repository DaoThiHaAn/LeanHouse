class LandlordPortal::InvoicesController < LandlordPortal::BaseController
  layout "house_mngment"

  before_action :set_billing_month, only: %i[index filtered new]
  before_action :set_invoice, only: %i[show mark_paid cancel]

  def index
    load_invoices
  end

  def filtered
    load_invoices
    render partial: "invoices_table", locals: { house: @house, invoices: @invoices, billing_month: @billing_month }
  end

  def show
    @items = @invoice.invoice_items.order(created_at: :asc)
    @bank_account = @invoice.bank_account || @landlord.bank_accounts.default_first.first
  end

  def new
    @room = @house.rooms.find_by(id: params[:room_id]) || @house.rooms.active.first
    @billing_month = (params[:month]&.to_date || Date.current).beginning_of_month
    @invoice_type = params[:invoice_type].presence || "room"
    @tenant = @room&.tenants&.find_by(id: params[:tenant_id]) || @room&.tenants&.first
    @bank_accounts = @landlord.bank_accounts.includes(:bank).default_first

    if @room
      calculator = Invoices::DraftCalculator.new(
        room: @room,
        billing_month: @billing_month,
        invoice_type: @invoice_type,
        tenant: @tenant
      )
      @draft_items = calculator.build_items
    else
      @draft_items = []
    end
  end

  def preview
    @room = @house.rooms.find(params[:room_id])
    @billing_month = (params[:month]&.to_date || Date.current).beginning_of_month
    @invoice_type = params[:invoice_type].presence || "room"
    @tenant = @room.tenants.find_by(id: params[:tenant_id]) if params[:tenant_id].present?

    calculator = Invoices::DraftCalculator.new(
      room: @room,
      billing_month: @billing_month,
      invoice_type: @invoice_type,
      tenant: @tenant
    )
    @draft_items = calculator.build_items

    render partial: "draft_items_form", locals: {
      room: @room,
      billing_month: @billing_month,
      invoice_type: @invoice_type,
      tenant: @tenant,
      draft_items: @draft_items
    }
  end

  def create
    @room = @house.rooms.find(params[:invoice][:room_id])
    @billing_month = Date.parse("#{params[:invoice][:billing_month]}-01") rescue Date.current.beginning_of_month

    @invoice = Invoices::IssueService.call(
      room: @room,
      billing_month: @billing_month,
      landlord: current_user,
      params: invoice_params
    )

    redirect_to landlord_house_invoice_path(@house, @invoice), notice: "Đã xuất hóa đơn #{@invoice.code} thành công!"
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = "Không thể tạo hóa đơn: #{e.record.errors.full_messages.to_sentence}"
    @bank_accounts = @landlord.bank_accounts.includes(:bank).default_first
    render :new, status: :unprocessable_entity
  end

  def mark_paid
    payment_method = params[:payment_method].presence || "cash"
    @invoice.mark_as_paid!(payment_method)

    redirect_to landlord_house_invoice_path(@house, @invoice), notice: "Đã xác nhận thanh toán hóa đơn #{@invoice.code}!"
  end

  def cancel
    Invoices::CancelService.call(invoice: @invoice, cancelled_by: current_user)
    redirect_to landlord_house_invoices_path(@house, month: @invoice.billing_month.strftime("%Y-%m")), notice: "Đã hủy hóa đơn #{@invoice.code}!"
  end

  private

  def set_billing_month
    @billing_month = if params[:month].present?
                       Date.parse("#{params[:month]}-01").beginning_of_month rescue Date.current.beginning_of_month
    else
                       Date.current.beginning_of_month
    end
  end

  def load_invoices
    @invoices = @house.invoices
                      .for_month(@billing_month)
                      .includes(:room, :tenant, :bank_account, :created_by)
                      .sorted

    if params[:status].present? && Invoice.statuses.key?(params[:status])
      @invoices = @invoices.where(status: params[:status])
    end

    if params[:room_id].present?
      @invoices = @invoices.where(room_id: params[:room_id])
    end
  end

  def set_invoice
    @invoice = @house.invoices.find(params[:id])
  end

  def invoice_params
    params.require(:invoice).permit(
      :room_id, :tenant_id, :bank_account_id, :invoice_type,
      :billing_month, :due_date, :note,
      items: [
        :selected, :item_type, :service_variant_id, :service_usage_log_id,
        :name, :unit, :unit_price, :quantity, :amount,
        :prev_reading, :latest_reading
      ]
    )
  end
end
