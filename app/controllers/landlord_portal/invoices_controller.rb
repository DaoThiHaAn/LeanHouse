class LandlordPortal::InvoicesController < LandlordPortal::BaseController
  layout "house_mngment"

  before_action :set_billing_month, only: %i[index filtered new preview]
  before_action :set_invoice, only: %i[show edit update mark_paid cancel]

  def index
    load_invoices_and_stats
  end

  def filtered
    load_invoices_and_stats
    render partial: "invoices_content", locals: {
      house: @house,
      invoices: @invoices,
      stats: @stats,
      billing_month: @billing_month,
      current_tenants_only: @current_tenants_only
    }
  end

  def show
    @items = @invoice.invoice_items.order(created_at: :asc)
    @bank_account = @invoice.bank_account || @landlord.bank_accounts.default_first.first
  end

  def new
    @room = @house.rooms.find_by(id: params[:room_id]) || @house.rooms.active.first
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
    @invoice_type = params[:invoice_type].presence || "room"
    @tenant = @room.tenants.find_by(id: params[:tenant_id]) if params[:tenant_id].present?
    if @tenant.nil? && @invoice_type == "individual"
      @tenant = @room.tenants.first
    end

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
    @billing_month = parse_month(params[:invoice][:billing_month])

    @invoice = Invoices::IssueService.call(
      room: @room,
      billing_month: @billing_month,
      landlord: current_user,
      params: invoice_params
    )

    redirect_to landlord_house_invoice_path(@house, @invoice), notice: "Đã xuất hóa đơn #{@invoice.code} thành công!"
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = "Không thể tạo hóa đơn: #{e.record.errors.full_messages.to_sentence}"
    @invoice_type = params[:invoice]&.[](:invoice_type).presence || "room"
    @tenant = @room&.tenants&.find_by(id: params[:invoice]&.[](:tenant_id)) if params[:invoice]&.[](:tenant_id).present?
    calculator = Invoices::DraftCalculator.new(
      room: @room,
      billing_month: @billing_month,
      invoice_type: @invoice_type,
      tenant: @tenant
    )
    @draft_items = calculator.build_items
    @bank_accounts = @landlord.bank_accounts.includes(:bank).default_first
    render :new, status: :unprocessable_entity
  end

  def edit
    @bank_accounts = @landlord.bank_accounts.includes(:bank).default_first
  end

  def update
    if Invoices::UpdateService.call(invoice: @invoice, house: @house, params: invoice_update_params)
      redirect_to landlord_house_invoice_path(@house, @invoice), notice: t("invoice.update_success")
    else
      flash.now[:alert] = @invoice.errors.full_messages.to_sentence
      @bank_accounts = @landlord.bank_accounts.includes(:bank).default_first
      render :edit, status: :unprocessable_entity
    end
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
    @billing_month = parse_month(params[:month])
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

  def load_invoices_and_stats
    @current_tenants_only = params[:current_tenants_only].nil? || params[:current_tenants_only] == "1"
    @invoices = Invoices::FilterService.call(
      house: @house,
      params: params,
      billing_month: @billing_month,
      current_tenants_only: @current_tenants_only
    )
    @stats = Invoices::StatsService.call(invoices: @invoices)
  end

  def set_invoice
    @invoice = @house.invoices.find(params[:id])
  end

  def invoice_params
    params.require(:invoice).permit(
      :room_id, :tenant_id, :bank_account_id, :invoice_type,
      :billing_month, :due_date, :start_date, :end_date, :title, :note,
      items: [
        :selected, :item_type, :service_variant_id, :service_usage_log_id,
        :name, :unit, :unit_price, :quantity, :amount,
        :start_date, :end_date, :prev_reading, :latest_reading, :note
      ]
    )
  end

  def invoice_update_params
    params.require(:invoice).permit(
      :start_date, :end_date, :due_date, :title, :note, :bank_account_id
    )
  end
end
