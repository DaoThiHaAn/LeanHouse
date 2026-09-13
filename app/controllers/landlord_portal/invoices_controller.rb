class LandlordPortal::InvoicesController < LandlordPortal::BaseController
  layout "house_mngment"

  before_action :set_billing_month, only: %i[index filtered new preview]
  before_action :set_invoice, only: %i[show edit update mark_paid undo_paid cancel]
  before_action :ensure_invoice_editable, only: %i[edit update]
  before_action :ensure_invoice_cancellable, only: %i[cancel]

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
      current_tenants_only: @current_tenants_only,
      current_tab: @current_tab
    }
  end

  def show
    @items = @invoice.invoice_items.order(created_at: :asc)
    @bank_account = @invoice.bank_account || @landlord.bank_accounts.default_first.first
  end

  def new
    @mode = params[:mode].presence || "standard"
    if @mode == "custom"
      load_new_custom_invoice_form_data
    else
      load_new_invoice_form_data
      @room = if params[:room_id].present?
                @occupied_rooms.find { |r| r.id.to_s == params[:room_id].to_s }
      end
      @invoice_type = params[:invoice_type].presence || "room"
      @tenant = @room&.tenants&.find_by(id: params[:tenant_id])
      if @tenant.nil? && @invoice_type == "individual" && @room.present?
        @tenant = @room.tenants.first
      end

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
  end

  def preview
    if params[:room_id].blank?
      render partial: "draft_items_form", locals: {
        room: nil,
        billing_month: @billing_month,
        invoice_type: params[:invoice_type].presence || "room",
        tenant: nil,
        draft_items: []
      }
      return
    end

    rooms_query = Invoices::OccupiedRoomsQuery.call(@house)
    @room = rooms_query[:occupied_rooms].find { |r| r.id.to_s == params[:room_id].to_s } || @house.rooms.find(params[:room_id])
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
    @mode = params[:mode].presence || params.dig(:invoice, :mode).presence || "standard"
    if @mode == "custom"
      result = Invoices::CreateCustomService.call(
        house: @house,
        landlord: current_user,
        params: custom_invoice_params
      )

      if result.success?
        if result.invoices.size == 1
          redirect_to landlord_house_invoice_path(@house, result.invoices.first),
                      notice: I18n.t("invoice.custom_create_success_single", code: result.invoices.first.code, default: "Đã xuất hóa đơn #{result.invoices.first.code} thành công!")
        else
          redirect_to landlord_house_invoices_path(@house, month: parse_month(params.dig(:invoice, :billing_month)).strftime("%Y-%m"), tab: "individual"),
                      notice: I18n.t("invoice.custom_create_success_multiple", count: result.invoices.size, default: "Đã xuất thành công #{result.invoices.size} hóa đơn cho các người thuê được chọn!")
        end
      else
        flash.now[:alert] = result.error_message
        @billing_month = parse_month(params.dig(:invoice, :billing_month))
        load_new_custom_invoice_form_data
        render :new, status: :unprocessable_entity
      end
      return
    end

    @billing_month = parse_month(params.dig(:invoice, :billing_month))
    @room = @house.rooms.find_by(id: params.dig(:invoice, :room_id))
    unless @room
      flash.now[:alert] = I18n.t("invoice.select_room_prompt", default: "Vui lòng chọn phòng")
      load_new_invoice_form_data
      @invoice_type = params[:invoice]&.[](:invoice_type).presence || "room"
      @draft_items = []
      render :new, status: :unprocessable_entity
      return
    end

    @invoice = Invoices::IssueService.call(
      room: @room,
      billing_month: @billing_month,
      landlord: current_user,
      params: invoice_params
    )

    redirect_to landlord_house_invoice_path(@house, @invoice), notice: "Đã xuất hóa đơn #{@invoice.code} thành công!"
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = "Không thể tạo hóa đơn: #{e.record.errors.full_messages.to_sentence}"
    load_new_invoice_form_data
    @invoice_type = params[:invoice]&.[](:invoice_type).presence || "room"
    @tenant = @room&.tenants&.find_by(id: params[:invoice]&.[](:tenant_id)) if params[:invoice]&.[](:tenant_id).present?
    calculator = Invoices::DraftCalculator.new(
      room: @room,
      billing_month: @billing_month,
      invoice_type: @invoice_type,
      tenant: @tenant
    )
    @draft_items = calculator.build_items
    render :new, status: :unprocessable_entity
  end

  def edit
    @bank_accounts = @landlord.bank_accounts.includes(:bank).default_first
  end

  def update
    if Invoices::UpdateService.call(invoice: @invoice, house: @house, params: invoice_update_params)
      @billing_month = @invoice.billing_month
      load_invoices_and_stats
      flash.now[:notice] = t("invoice.update_success")
      respond_to do |format|
        if params[:return_to] == "show"
          format.html { redirect_to landlord_house_invoice_path(@house, @invoice), notice: t("invoice.update_success") }
          format.turbo_stream { redirect_to landlord_house_invoice_path(@house, @invoice), notice: t("invoice.update_success") }
        else
          format.turbo_stream
          format.html { redirect_to landlord_house_invoice_path(@house, @invoice), notice: t("invoice.update_success") }
        end
      end
    else
      flash.now[:alert] = @invoice.errors.full_messages.to_sentence
      @bank_accounts = @landlord.bank_accounts.includes(:bank).default_first
      respond_to do |format|
        format.turbo_stream { render :edit, status: :unprocessable_entity }
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def mark_paid
    Invoices::MarkPaidService.call(
      invoice: @invoice,
      paid_by: current_user,
      params: payment_params
    )

    respond_to do |format|
      format.turbo_stream do
        @billing_month = @invoice.billing_month
        load_invoices_and_stats
        flash.now[:notice] = "Đã xác nhận thanh toán hóa đơn #{@invoice.code}!"
        render :update
      end
      format.html { redirect_to landlord_house_invoice_path(@house, @invoice), notice: "Đã xác nhận thanh toán hóa đơn #{@invoice.code}!" }
    end
  end

  def undo_paid
    Invoices::UndoPaidService.call(
      invoice: @invoice,
      undone_by: current_user,
      explanation: params[:explanation]
    )

    respond_to do |format|
      format.turbo_stream do
        @billing_month = @invoice.billing_month
        load_invoices_and_stats
        flash.now[:notice] = "Đã hủy xác nhận thanh toán cho hóa đơn #{@invoice.code}!"
        render :update
      end
      format.html { redirect_to landlord_house_invoice_path(@house, @invoice), notice: "Đã hủy xác nhận thanh toán cho hóa đơn #{@invoice.code}!" }
    end
  rescue ArgumentError => e
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = e.message
        render :update, status: :unprocessable_entity
      end
      format.html { redirect_to landlord_house_invoice_path(@house, @invoice), alert: e.message }
    end
  end

  def cancel
    Invoices::CancelService.call(invoice: @invoice, cancelled_by: current_user)
    redirect_to landlord_house_invoices_path(@house, month: @invoice.billing_month.strftime("%Y-%m"), tab: (@invoice.custom? ? "individual" : "room")), notice: "Đã hủy hóa đơn #{@invoice.code}!"
  rescue ArgumentError => e
    redirect_to landlord_house_invoice_path(@house, @invoice), alert: e.message
  end

  private

  def ensure_invoice_editable
    return unless @invoice.paid?

    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = t("invoice.errors.cannot_update_paid", default: "Không thể chỉnh sửa hóa đơn đã xác nhận thanh toán. Vui lòng hủy xác nhận thanh toán trước nếu cần thay đổi.")
        render :update, status: :unprocessable_entity
      end
      format.html do
        redirect_to landlord_house_invoice_path(@house, @invoice),
                    alert: t("invoice.errors.cannot_update_paid", default: "Không thể chỉnh sửa hóa đơn đã xác nhận thanh toán. Vui lòng hủy xác nhận thanh toán trước nếu cần thay đổi.")
      end
    end
  end

  def ensure_invoice_cancellable
    return unless @invoice.paid?

    redirect_to landlord_house_invoice_path(@house, @invoice),
                alert: t("invoice.errors.cannot_cancel_paid", default: "Không thể hủy hóa đơn đã xác nhận thanh toán. Vui lòng hủy xác nhận thanh toán trước.")
  end

  def payment_params
    params.fetch(:invoice, params).permit(:payment_method, :payment_proof, :note)
  end

  def set_billing_month
    @billing_month = parse_month(params[:month])
  end

  def parse_month(str)
    return Date.current.beginning_of_month if str.blank?

    str_val = str.to_s.strip
    if (m = str_val.match(/\A(\d{4})[-.\/](\d{1,2})\z/))
      year = m[1].to_i
      month = m[2].to_i
      return Date.new(year, month, 1) if month.between?(1, 12) && year.between?(2000, 2100)
    end

    begin
      Date.parse("#{str_val}-01").beginning_of_month
    rescue StandardError
      Date.current.beginning_of_month
    end
  end

  INVOICES_PER_PAGE = 15

  def load_invoices_and_stats
    @current_tab = params[:tab].presence || "room"
    @current_tenants_only = params[:current_tenants_only].nil? || params[:current_tenants_only] == "1"

    # 1. Base monthly scope for tab badge counts (complete monthly overview)
    all_month_invoices = @house.invoices.kept.for_month(@billing_month)
    @room_count = all_month_invoices.where(invoice_type: %w[room individual]).count
    @individual_count = all_month_invoices.where(invoice_type: "custom").count

    # 2. Dashboard stats: stable monthly overview for the active tab (INDEPENDENT of toolbar filters and current_tenants_only)
    tab_overview_scope = if @current_tab == "individual"
                           all_month_invoices.where(invoice_type: "custom")
    else
                           all_month_invoices.where(invoice_type: %w[room individual])
    end
    @stats = Invoices::StatsService.call(invoices: tab_overview_scope)

    # 3. Invoices table: filtered by active tab + all toolbar filters (floor, room, payment_mode/invoice_type, status, q, current_tenants_only, page)
    filtered_scope = Invoices::FilterService.call(
      house: @house,
      params: params.merge(tab: @current_tab),
      billing_month: @billing_month,
      current_tenants_only: @current_tenants_only
    )
    @invoices = filtered_scope.page(params[:page]).per(INVOICES_PER_PAGE)
  end

  def set_invoice
    @invoice = @house.invoices.find(params[:id])
  end

  def invoice_params
    params.require(:invoice).permit(
      :room_id, :tenant_id, :bank_account_id, :invoice_type,
      :billing_month, :due_date, :start_date, :end_date, :title, :note,
      :transfer_note, :transfer_note_mode,
      items: [
        :selected, :item_type, :service_variant_id, :service_usage_log_id,
        :name, :unit, :unit_price, :quantity, :amount,
        :start_date, :end_date, :prev_reading, :latest_reading, :note
      ]
    )
  end

  def invoice_update_params
    params.require(:invoice).permit(
      :start_date, :end_date, :due_date, :title, :note, :bank_account_id,
      :transfer_note, :transfer_note_mode
    )
  end

  def load_new_invoice_form_data
    rooms_query = Invoices::OccupiedRoomsQuery.call(@house)
    @occupied_rooms = rooms_query[:occupied_rooms]
    @floors = rooms_query[:floors]
    @rooms_json_data = rooms_query[:rooms_data]
    @bank_accounts = @landlord.bank_accounts.includes(:bank).default_first
  end

  def load_new_custom_invoice_form_data
    @staying_tenants = @house.all_staying_tenants_list
    @bank_accounts = @landlord.bank_accounts.includes(:bank).default_first
  end

  def custom_invoice_params
    params.require(:invoice).permit(
      :billing_month, :due_date, :start_date, :end_date, :title, :note, :bank_account_id,
      :transfer_note, :transfer_note_mode,
      tenant_ids: [],
      items: [
        :selected, :item_type, :name, :unit, :unit_price, :quantity, :amount, :note
      ]
    )
  end
end
